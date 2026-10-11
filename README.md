# FPSごっこ

> **「弟が全部倒しといたから。」**

**FPSごっこ** は、FPSをやったことがない姉が「FPSやってるよ！」と冗談で言いたくて作る、ゆるいiOSゲームです。

敵に撃たれません。

ゲームオーバーもありません。

敵は最初から全員倒れています。

FPSの「怖い部分」をすべて取り除き、

**撃つ・狙う・リロードする**

そんな「FPSやってる感」だけを楽しむゲームです。

## 現在の状態

SwiftUI＋RealityKitによるiPhone向けMVPを実装しています。タイトル → 60秒のゲーム → リザルト → Play Againの3画面で構成します。

- HTMLモックはUI仕様書として保持し、色・四角い部品・コピーをSwiftUIへ移植しています。
- ゲームは移動・視点操作・射撃・即時リロードに対応。武器は1種類で、設定と武器変更は表示のみです。
- 18発、命中+100点、命中率、2秒以内の連続命中コンボを集計します。倒れたダミーは1つの物理Bodyとして反応します。
- 外部ライブラリ・外部素材・永続化・アプリ内ネットワーク通信はありません。フォントはApple標準の等幅フォントへフォールバックしています。

## iOSアプリの起動・検証

`app/FPSPretend.xcodeproj`をXcodeで開き、`FPSPretend` schemeとiPhone Simulatorを選んでRunします。対応はiOS 17以降・iPhone・縦画面です。実機で実行する場合はSigningのTeamと必要に応じてBundle Identifierを設定してください。

```sh
xcodebuild -project app/FPSPretend.xcodeproj -scheme FPSPretend \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/TryFPS-build CODE_SIGNING_ALLOWED=NO build

# 利用可能なiPhone Simulator名に置き換えて実行
xcodebuild -project app/FPSPretend.xcodeproj -scheme FPSPretend \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath /tmp/TryFPS-build -parallel-testing-enabled NO \
  CODE_SIGNING_ALLOWED=NO test
```

テストは状態の境界条件、描画中のRay命中・物理Impulse・前後左右の移動、および実時間60秒の画面遷移と再プレイを確認します。UIテストには3画面のスクリーンショットが添付されます。

Simulatorでの検証と実機性能は区別しています。実機での60FPS・起動速度は未計測です。

## モックの確認方法

[UIデザインモック](mock/html/index.html)をブラウザで開いてください。Tailwind CSSとGoogle Fontsを外部から読み込むため、インターネット接続が必要です。

ローカルサーバーを使う場合は、リポジトリのルートで実行します。

```sh
python3 -m http.server 8791 --bind 127.0.0.1
```

ブラウザで <http://127.0.0.1:8791/mock/html/index.html> を開きます。終了は `Ctrl+C` です。

## 開発資料

[業務設計書](docs/業務設計書.md)に、MVPの範囲・画面・機能・開発段階・完了条件をまとめています。

---

# コンセプト

ある日。

ゲーム音痴な姉は、弟が毎日FPSを遊んでいる姿を見て思いました。

> 「私もFPSやってみたい。」

でも実際に遊ぶと、

- 敵が怖い
- 急に撃たれる
- 何が起きているか分からない

開始5秒で終了。

すると弟が一言。

> 「じゃあ敵全部倒しといたから。」

そこから始まる、

世界一平和なFPS。

---

# ゲーム概要

プレイヤーはFPSの操作だけを楽しみます。

- 移動
- 視点操作
- 射撃
- リロード
- 武器変更UI（MVPは1種類・切り替えなし）

敵AIは存在しません。

ゲームオーバーもありません。

安心して「FPSごっこ」ができます。

---

# 開発目的

このプロジェクトの目的は2つあります。

## 1. RealityKitを学ぶ

ゲーム制作経験がないため、

小さく完成させながらRealityKitを学ぶ教材として開発します。

## 2. 自分が遊びたいゲームを作る

市場調査から始めるのではなく、

「自分だったら遊びたい」

と思えるゲームを完成させます。

---

# デザインコンセプト

テーマ

- ゆるい
- レトロ
- ファミコン
- ゲームボーイ
- Nintendoらしい楽しさ

キーワード

- 四角いUI
- ドットフォント
- 最小限の色
- 余白を大切にする
- 可愛い
- シンプル

リアルなFPSではなく、

「優しいゲーム機」

のようなデザインを目指します。

---

# 技術スタック（iOS MVP）

- SwiftUI
- RealityKit
- Swift
- Xcode

外部ライブラリは使用しません（iOS MVP時点）。現在のHTMLモックで使用しているTailwind CSS・Webフォントとは区別します。


---

# ディレクトリ

```text
TryFPS/
├── README.md
├── docs/                 # 業務設計書など
├── design/               # デザイン資料用（現在は空）
├── mock/html/index.html  # 静的UIモック
└── app/                  # Xcodeプロジェクト・SwiftUI/RealityKit実装・テスト
```

シンプルさを維持するため、

必要になるまでディレクトリは増やしません。

---

# スコープ

MVPでは実装しないもの。

- オンライン
- ランキング
- ログイン
- 課金
- セーブデータ
- API
- バックエンド
- マルチプレイ
- AI
- 広告
- アカウント
- 実績解除
- スキン
- 武器収集

---

# Design Philosophy

ゲーム性より、

**世界観**

を作る。

難しさより、

**触っていて気持ちいい**

を目指す。

「上手くなるゲーム」ではなく、

「FPSをやってる気分になれるゲーム」

を作る。

---

# Vision

このゲームは、

「自分のためにゲームを作ってみたい」

という小さな好奇心から始まったプロジェクトです。

---

# License

Private Project
Copyright © 2026 Yuuri Masui
