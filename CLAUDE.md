# DisplayLayout

macのメニューバー常駐アプリ。「システム設定 > ディスプレイ > 配置」と同等の機能に即座にアクセスできるようにする。メニューバーアイコンをクリックするとポップオーバーが開き、接続中のディスプレイがシンプルな矩形として表示され、ドラッグで実際のディスプレイ配置を変更できる。

## ビルド・実行

Swift Package Manager プロジェクト(Xcodeプロジェクトファイルは不要、`Package.swift` をXcodeで直接開ける)。

```sh
swift build            # ビルド
swift run              # 起動(メニューバーにアイコンが出る。Dockには出ない)
swift build -c release # リリースビルド → .build/release/DisplayLayout
```

終了はメニューバーアイコンの右クリック→「終了」。

## インストール・自動起動

```sh
scripts/install.sh
```

リリースビルド → `~/Applications/DisplayLayout.app` として配置(最小限のInfo.plist、`LSUIElement`)→ System Events 経由でログイン項目(hidden)に登録してログイン時に自動起動+即時起動、まで行う。コード更新後もこのスクリプトを再実行するだけでよい(既存インスタンスは停止して差し替える)。LaunchAgent ではなくログイン項目を使うのは、ad-hoc署名 + LaunchAgent の組み合わせで macOS が起動のたびに「バックグラウンドでのアクティビティ」通知を出すため。

- 自動起動の解除: 「システム設定 > 一般 > ログイン項目」で DisplayLayout を削除、または `osascript -e 'tell application "System Events" to delete login item "DisplayLayout"'`
- ログイン項目なので手動で終了しても勝手に再起動しない(次回ログイン時にまた起動する)
- 初回実行時、ターミナルから System Events を制御する自動化の許可ダイアログが表示される場合がある

## アーキテクチャ

- `Sources/DisplayLayout/main.swift` — エントリポイント。`.accessory` ポリシーでDockアイコン非表示(Info.plist不要)
- `Sources/DisplayLayout/AppDelegate.swift` — `NSStatusItem` 管理。左クリック→`NSPopover` トグル、右クリック→終了メニュー
- `Sources/DisplayLayout/DisplayManager.swift` — CoreGraphics公開APIのラッパー。取得: `CGGetActiveDisplayList` + `CGDisplayBounds`、適用: `CGBeginDisplayConfiguration` → `CGConfigureDisplayOrigin` → `CGCompleteDisplayConfiguration(.permanently)`
- `Sources/DisplayLayout/ArrangementView.swift` — 配置編集UI。ドラッグ中の辺スナップ、mouseUp時の重なり解消・連結保証(ディスプレイ群が非連結だとmacOSが受け付けない)→ 適用

## 座標系の注意

- CGグローバルディスプレイ座標: 原点=メインディスプレイ左上、**+yは下方向**。`ArrangementView` は `isFlipped = true` で座標系を一致させている
- `CGConfigureDisplayOrigin` 適用後、システム側で座標が正規化される(メインが常に(0,0))ため、適用後は必ず `activeDisplays()` で再取得する(0.5秒遅延で再読込)
- 外部からの配置変更は `NSApplication.didChangeScreenParametersNotification` で検知して再読込

## 制約・方針

- 外部依存なし。AppKit + CoreGraphics の公開APIのみ(CGS系のprivate APIは使わない)。特別な権限・entitlementは不要
- swift-tools-version は **5.9 のまま維持**(Swift 5言語モードにして AppKit との strict concurrency 問題を回避)
- UI文字列は日本語

## 開発の進め方

計画・設計・レビューは上位モデル(メインエージェント)が行い、コード実装の作業はSonnetのサブエージェント(Agentツール、`model: "sonnet"`)に委任してトークン消費を抑える。
