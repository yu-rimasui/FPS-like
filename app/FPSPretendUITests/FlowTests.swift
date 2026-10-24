import XCTest

final class FlowTests: XCTestCase {
    @MainActor func testShotsAtMovingDollsConsumeAmmoAndKeepSavedProgress() {
        let app = XCUIApplication()
        app.launch()
        selectFirstStage(app)
        let savedProgress = app.staticTexts["stageProgress"].label
        XCTAssertTrue(savedProgress.contains("0/15"))
        app.buttons["fireButton"].tap(withNumberOfTaps: 5, numberOfTouches: 1)
        XCTAssertTrue(app.staticTexts["ammoLabel"].label.contains("13"))
        XCTAssertTrue(app.buttons["fireButton"].isEnabled)
        capture("ShotsAtMovingDolls", app: app)
        app.buttons["fireButton"].tap()
        XCTAssertTrue(app.staticTexts["ammoLabel"].label.contains("12"))
        app.buttons["leaveStageButton"].tap()
        let saved = app.staticTexts["savedProgress"].label
        app.terminate()
        app.launch()
        XCTAssertEqual(app.staticTexts["savedProgress"].label, saved)
        app.buttons["stageSelectButton"].tap()
        XCTAssertTrue(app.buttons["selectStage5"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["selectStage6"].exists)
        app.terminate()
    }

    @MainActor func testEncounterCollectionAndProgressPersistAfterRelaunch() {
        let app = XCUIApplication()
        app.launch()
        selectFirstStage(app)
        XCTAssertTrue(app.staticTexts["stageInstruction"].exists)
        capture("Game", app: app)
        app.buttons["fireButton"].tap()
        XCTAssertTrue(app.staticTexts["ammoLabel"].label.contains("17"))
        app.buttons["leaveStageButton"].tap()
        XCTAssertTrue(app.buttons["collectionButton"].waitForExistence(timeout: 10))
        let savedProgress = app.staticTexts["savedProgress"].label
        app.buttons["collectionButton"].tap()
        let collection = app.staticTexts["collectionProgress"]
        XCTAssertTrue(collection.waitForExistence(timeout: 10))
        let savedCollection = collection.label
        // Encounters persist even when an enemy has not yet been fully resolved.
        XCTAssertTrue(app.staticTexts["横になってる人形"].exists)
        XCTAssertTrue(app.staticTexts["歩いてる人形"].exists)
        XCTAssertFalse(savedCollection.contains("オチ"))
        XCTAssertTrue(savedCollection.hasSuffix("/7"))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "独自技術")).firstMatch.exists)
        capture("Collection", app: app)
        app.swipeUp()
        XCTAssertTrue(app.staticTexts["出会った人形の記録は、途中でやめても残ります。"].isHittable)
        capture("CollectionBottom", app: app)
        app.terminate()
        app.launch()
        XCTAssertEqual(app.staticTexts["savedProgress"].label, savedProgress)
        app.buttons["collectionButton"].tap()
        XCTAssertTrue(collection.waitForExistence(timeout: 10))
        XCTAssertEqual(collection.label, savedCollection)
        app.buttons["closeLibraryButton"].tap()
        app.buttons["stageSelectButton"].tap()
        XCTAssertTrue(app.buttons["selectStage1"].waitForExistence(timeout: 10))
        for (index, name) in ["壁", "風車", "ボール", "迷路", "隕石"].enumerated() {
            XCTAssertTrue(app.buttons["selectStage\(index + 1)"].label.contains("\(index + 1). \(name)"))
        }
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

    @MainActor func testSettingsReturnToStartAndRestart() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["settingsButton"].tap()
        XCTAssertTrue(app.buttons["closeSettingsButton"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["returnToStartButton"].exists)
        app.buttons["closeSettingsButton"].tap()
        selectFirstStage(app)
        app.buttons["fireButton"].tap()
        app.buttons["settingsButton"].tap()
        let back = app.buttons["returnToStartButton"]
        XCTAssertTrue(back.waitForExistence(timeout: 10))
        XCTAssertEqual(back.label, "スタートに戻る")
        capture("SettingsReturnToStart", app: app)
        back.tap()
        XCTAssertTrue(app.buttons["startButton"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["closeSettingsButton"].exists)
        XCTAssertFalse(app.buttons["fireButton"].exists)
        app.buttons["startButton"].tap()
        XCTAssertTrue(app.buttons["fireButton"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["stageLabel"].label.contains("1/5"))
        XCTAssertEqual(app.staticTexts["scoreLabel"].label, "000000")
        XCTAssertTrue(app.staticTexts["ammoLabel"].label.contains("18"))
        app.terminate()
    }

    @MainActor func testTimeoutRetryAndSettingsPause() async throws {
        let app = XCUIApplication()
        app.launch()
        capture("Title", app: app)
        selectFirstStage(app)
        func seconds(_ label: String) -> Int {
            let parts = label.split(separator: ":").compactMap { Int($0) }
            return parts.count == 2 ? parts[0] * 60 + parts[1] : -1
        }
        let before = seconds(app.staticTexts["timerLabel"].label)
        app.buttons["settingsButton"].tap()
        XCTAssertTrue(app.switches["shotSoundToggle"].waitForExistence(timeout: 10))
        try await Task.sleep(for: .seconds(3))
        app.buttons["closeSettingsButton"].tap()
        let after = seconds(app.staticTexts["timerLabel"].label)
        XCTAssertLessThanOrEqual(before - after, 1)
        XCTAssertTrue(app.buttons["replayButton"].waitForExistence(timeout: 95))
        XCTAssertEqual(app.staticTexts["resultStatus"].label, "ひと休み")
        capture("Timeout", app: app)
        app.buttons["replayButton"].tap()
        XCTAssertTrue(app.buttons["fireButton"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["stageLabel"].label.contains("1/5"))
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
        XCTAssertTrue(app.staticTexts["stageLabel"].label.contains("1/5"))
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
