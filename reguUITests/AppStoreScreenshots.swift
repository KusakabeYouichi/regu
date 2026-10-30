import XCTest

// App Store 用スクリーンショットの撮影。通常のテスト実行では全件スキップする。
// 環境変数 REGU_SCREENSHOT_DIR に出力先を渡したときだけ動き、PNG をそこへ書く。
//   TEST_RUNNER_REGU_SCREENSHOT_DIR=<dir> xcodebuild test ... -only-testing:reguUITests/AppStoreScreenshots
@MainActor
final class AppStoreScreenshots: XCTestCase {
    private static let allowPasteLabels = ["ペーストを許可", "Allow Paste"]
    private static let regularisationRow = "presetRow.6F1C2A10-0000-4000-8000-000000000001"

    func testScene01Regularisation() throws {
        let app = try launch(clipboard: "Ｃａｆe\u{301}　ｄｅ　ｌａ　Ｐａｉｘ　ﾃﾞｨﾅｰ２０㎏「予約」（１８：３０）")
        selectPresetIfNeeded("régularisation", app: app)
        try settleAndSave("01-regularisation", app: app)
    }

    func testScene02Adresse() throws {
        let app = try launch(clipboard: "練馬区時計坂3-3-9 一刻館5号室")
        selectPresetIfNeeded("Adresse héritée", app: app)
        try settleAndSave("02-adresse", app: app)
    }

    func testScene03Ruby() throws {
        let app = try launch(clipboard: "びびでぃばびでぃぶ")
        selectPresetIfNeeded("ruby héritée", app: app)
        try settleAndSave("03-ruby", app: app)
    }

    func testScene04Presets() throws {
        let app = try launch(clipboard: nil)
        app.buttons["settingsButton"].tap()
        XCTAssertTrue(element(Self.regularisationRow, in: app).waitForExistence(timeout: 5))
        try settleAndSave("04-presets", app: app)
    }

    func testScene05Editor() throws {
        let app = try launch(clipboard: nil)
        app.buttons["settingsButton"].tap()
        let row = element(Self.regularisationRow, in: app)
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        XCTAssertTrue(app.staticTexts["alphabet"].firstMatch.waitForExistence(timeout: 5))
        try settleAndSave("05-editor", app: app)
    }

    // MARK: - 補助

    // 出力先が指定されていないときはスキップ。クリップボードが nil なら空にして起動する
    private func launch(clipboard: String?) throws -> XCUIApplication {
        _ = try outputDirectory()
        let app = XCUIApplication()
        app.terminate()
        if let clipboard {
            UIPasteboard.general.string = clipboard
        } else {
            UIPasteboard.general.items = []
        }
        app.launchArguments = ["-reguUITestReset"]
        app.launch()
        if clipboard != nil {
            allowPasteOrWaitForOutput(app: app)
        }
        return app
    }

    // 起動時の自動変換は前回のプリセットで行われるので、違うときは選び直す(選んだだけでは変換されないので変換ボタンを押す)
    private func selectPresetIfNeeded(_ name: String, app: XCUIApplication) {
        let picker = app.buttons["presetPicker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        if picker.value as? String != name {
            picker.tap()
            let item = app.buttons[name].firstMatch
            XCTAssertTrue(item.waitForExistence(timeout: 5), "プリセットのメニューに \(name) が無い")
            item.tap()
            app.buttons["convertButton"].tap()
        }
        XCTAssertEqual(picker.value as? String, name)
    }

    private func outputDirectory() throws -> URL {
        guard let path = ProcessInfo.processInfo.environment["REGU_SCREENSHOT_DIR"], !path.isEmpty else {
            throw XCTSkip("REGU_SCREENSHOT_DIR が無いので撮影しない")
        }
        return URL(fileURLWithPath: path, isDirectory: true)
    }

    // 「コピーしました」の表示が消えるのを待ってから撮る
    private func settleAndSave(_ name: String, app: XCUIApplication) throws {
        let badge = element("copiedBadge", in: app)
        let deadline = Date().addingTimeInterval(5)
        while badge.exists && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.3)
        }
        Thread.sleep(forTimeInterval: 1)
        let directory = try outputDirectory()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let suffix = UIDevice.current.userInterfaceIdiom == .pad ? "ipad" : "iphone"
        let url = directory.appendingPathComponent("\(name)-\(suffix).png")
        try XCUIScreen.main.screenshot().pngRepresentation.write(to: url)
    }

    // 起動直後に、ペースト許可アラートが出る(押す)か、結果欄に値が入るまで待つ
    private func allowPasteOrWaitForOutput(app: XCUIApplication, timeout: TimeInterval = 10) {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let output = element("output", in: app)
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            for label in Self.allowPasteLabels {
                let button = springboard.buttons[label]
                if button.exists {
                    button.tap()
                    return
                }
            }
            if let value = output.value as? String, !value.isEmpty { return }
            Thread.sleep(forTimeInterval: 0.2)
        } while Date() < deadline
    }

    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }
}
