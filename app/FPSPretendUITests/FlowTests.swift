import XCTest

final class FlowTests: XCTestCase {
    @MainActor func testStageClearNextAndSavedUnlock() {
        let app = XCUIApplication()
        app.launch()
        selectFirstStage(app)
        let aim = app.otherElements["aimArea"]
        var yaw = 0.0
        var pitch = -0.26
        app.buttons["fireButton"].tap()
        let candidates: [(Double, Double)] = [(-2, -6), (2, -6), (2, -3.5), (-2, -3.5), (0.5, -9), (-0.5, -9)]
        for (x, z) in candidates {
            if !app.buttons["fireButton"].isEnabled { break }
            let nextYaw = atan2(-x, 3 - z)
            let nextPitch = atan2(0.46 - 1.6, hypot(x, z - 3))
            let center = aim.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            center.press(forDuration: 0.05, thenDragTo: center.withOffset(CGVector(dx: -(nextYaw - yaw) / 0.005,
                                                                                dy: (pitch - nextPitch) / 0.005)))
            yaw = nextYaw
            pitch = nextPitch
            app.buttons["fireButton"].tap()
        }
        XCTAssertTrue(app.buttons["nextStageButton"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["resultEnding"].exists)
        capture("StageClear", app: app)
        app.buttons["nextStageButton"].tap()
        XCTAssertTrue(app.staticTexts["stageLabel"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["stageLabel"].label.contains("2/10"))
        XCTAssertTrue(app.staticTexts["stageLabel"].label.contains("あと5分ふとん"))
        XCTAssertEqual(app.staticTexts["scoreLabel"].label, "000000")
        capture("NextStage", app: app)
        app.buttons["leaveStageButton"].tap()
        let saved = app.staticTexts["savedProgress"].label
        app.terminate()
        app.launch()
        XCTAssertEqual(app.staticTexts["savedProgress"].label, saved)
        app.buttons["stageSelectButton"].tap()
        XCTAssertTrue(app.buttons["selectStage2"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["selectStage2"].isEnabled)
        app.terminate()
    }

    @MainActor func testEncounterCollectionAndProgressPersistAfterRelaunch() {
        let app = XCUIApplication()
        app.launch()
        selectFirstStage(app)
        XCTAssertTrue(app.staticTexts["stageInstruction"].exists)
        capture("Game", app: app)
        app.buttons["fireButton"].tap()
        XCTAssertEqual(app.staticTexts["scoreLabel"].label, "000100")
        app.buttons["leaveStageButton"].tap()
        XCTAssertTrue(app.buttons["collectionButton"].waitForExistence(timeout: 10))
        let savedProgress = app.staticTexts["savedProgress"].label
        app.buttons["collectionButton"].tap()
        let collection = app.staticTexts["collectionProgress"]
        XCTAssertTrue(collection.waitForExistence(timeout: 10))
        let savedCollection = collection.label
        XCTAssertFalse(savedCollection.contains("オチ 0/30"))
        XCTAssertTrue(app.staticTexts["通知スライム"].exists)
        capture("Collection", app: app)
        app.terminate()
        app.launch()
        XCTAssertEqual(app.staticTexts["savedProgress"].label, savedProgress)
        app.buttons["collectionButton"].tap()
        XCTAssertTrue(collection.waitForExistence(timeout: 10))
        XCTAssertEqual(collection.label, savedCollection)
        app.buttons["closeLibraryButton"].tap()
        app.buttons["stageSelectButton"].tap()
        XCTAssertTrue(app.buttons["selectStage1"].waitForExistence(timeout: 10))
        capture("StageSelection", app: app)
        app.terminate()
    }

    @MainActor func testSoundStyleVolumeAndHapticsPersistAfterRelaunch() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["settingsButton"].tap()
        let toggle = app.switches["shotSoundToggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 10))
        let initiallyEnabled = toggle.value as? String == "1"
        if !initiallyEnabled { toggle.tap() }
        let slider = app.sliders["soundVolumeSlider"]
        let originalVolume = Double((slider.value as? String ?? "65%").replacingOccurrences(of: "%", with: "")) ?? 65
        let haptics = app.switches["hapticsToggle"]
        let originalHaptics = haptics.value as? String == "1"
        let originalStyle = ["ポップ", "おもちゃ", "やわらか"].first { app.buttons[$0].isSelected } ?? "ポップ"
        defer {
            if toggle.value as? String != "1" { toggle.tap() }
            slider.adjust(toNormalizedSliderPosition: originalVolume / 100)
            app.buttons[originalStyle].tap()
            if (haptics.value as? String == "1") != originalHaptics { haptics.tap() }
            if !initiallyEnabled { toggle.tap() }
            app.buttons["closeSettingsButton"].tap()
            app.terminate()
        }
        slider.adjust(toNormalizedSliderPosition: 0.31)
        app.buttons["やわらか"].tap()
        XCTAssertTrue(app.buttons["やわらか"].isSelected)
        let selectedVolume = app.staticTexts["soundVolumeLabel"].label
        app.buttons["previewSoundButton"].tap()
        if haptics.value as? String == "1" { haptics.tap() }
        capture("Settings", app: app)
        toggle.tap()
        XCTAssertFalse(slider.isEnabled)
        XCTAssertFalse(app.buttons["previewSoundButton"].isEnabled)
        app.terminate()
        app.launch()
        app.buttons["settingsButton"].tap()
        XCTAssertTrue(toggle.waitForExistence(timeout: 10))
        XCTAssertEqual(toggle.value as? String, "0")
        XCTAssertEqual(app.staticTexts["soundVolumeLabel"].label, selectedVolume)
        XCTAssertEqual(haptics.value as? String, "0")
        XCTAssertFalse(slider.isEnabled)
        toggle.tap()
        XCTAssertTrue(app.buttons["やわらか"].isSelected)
        XCTAssertTrue(slider.isEnabled)
    }

    @MainActor func testTimeoutRetryAndSettingsPause() async throws {
        let app = XCUIApplication()
        app.launch()
        capture("Title", app: app)
        selectFirstStage(app)
        let before = Int(app.staticTexts["timerLabel"].label.suffix(2)) ?? 0
        app.buttons["settingsButton"].tap()
        XCTAssertTrue(app.switches["shotSoundToggle"].waitForExistence(timeout: 10))
        try await Task.sleep(for: .seconds(3))
        app.buttons["closeSettingsButton"].tap()
        let after = Int(app.staticTexts["timerLabel"].label.suffix(2)) ?? 0
        XCTAssertLessThanOrEqual(before - after, 1)
        XCTAssertTrue(app.buttons["replayButton"].waitForExistence(timeout: 40))
        XCTAssertEqual(app.staticTexts["resultStatus"].label, "ひと休み")
        capture("Timeout", app: app)
        app.buttons["replayButton"].tap()
        XCTAssertTrue(app.buttons["fireButton"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["stageLabel"].label.contains("1/10"))
        XCTAssertEqual(app.staticTexts["scoreLabel"].label, "000000")
        XCTAssertTrue(app.staticTexts["ammoLabel"].label.contains("18"))
        app.terminate()
    }

    @MainActor private func selectFirstStage(_ app: XCUIApplication) {
        XCTAssertTrue(app.buttons["stageSelectButton"].waitForExistence(timeout: 15))
        app.buttons["stageSelectButton"].tap()
        XCTAssertTrue(app.buttons["selectStage1"].waitForExistence(timeout: 10))
        app.buttons["selectStage1"].tap()
        XCTAssertTrue(app.buttons["fireButton"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["stageLabel"].label.contains("1/10"))
    }

    @MainActor private func capture(_ name: String, app: XCUIApplication) {
        let familyText = NSPredicate(format: "label MATCHES %@", ".*[姉弟兄妹].*")
        XCTAssertFalse(app.descendants(matching: .any).matching(familyText).firstMatch.exists)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
