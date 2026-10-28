import XCTest

// E2E 計画（c01-e2e-plan.md）の E1–E9 を XCUITest で行う。
// クリップボードはテストランナーから UIPasteboard.general で読み書きする（simctl pbcopy の代わり）。
// 各テストは -reguUITestReset 付きの起動から始め、前のテストの状態に依存しない
@MainActor
final class ReguE2EUITests: XCTestCase {
    private static let allowPasteLabels = ["ペーストを許可", "Allow Paste"]
    private static let e1Input = "ＡＢＣ１２３　ｶﾀｶﾅ「x」㎜"
    private static let e1Output = "ABC123 カタカナ『x』mm"

    // MARK: - E1–E7, E9（iPhone）

    func testE1_LaunchConvertsClipboardWithDefaultPreset() throws {
        try requireIdiom(.phone)
        let app = XCUIApplication()
        launchWithClipboard(Self.e1Input, app: app)

        XCTAssertEqual(element("input", in: app).value as? String, Self.e1Input)
        assertSelectedPreset("régularisation", app: app)
        waitForValue(Self.e1Output, of: element("output", in: app))
        capture("E1-iphone-after-launch")
        attachText("E1-iphone-hierarchy", app.debugDescription)
        XCTAssertEqual(readPasteboard(), Self.e1Output)
    }

    func testE2_ReturningFromHomeWithOwnOutputDoesNotChangeAnything() throws {
        try requireIdiom(.phone)
        let app = XCUIApplication()
        launchWithClipboard(Self.e1Input, app: app)
        waitForValue(Self.e1Output, of: element("output", in: app))

        goHomeAndReturn(app: app)
        let alertShown = allowPasteIfPrompted(timeout: 3)

        // 再変換が起きたかどうかは、続く input の assertion で検出する
        XCTAssertFalse(alertShown, "前提「自分の出力を読むときはペースト許可が出ない」が崩れた")
        XCTAssertEqual(element("input", in: app).value as? String, Self.e1Input)
        XCTAssertEqual(element("output", in: app).value as? String, Self.e1Output)
        capture("E2-iphone-after-return")
        XCTAssertEqual(readPasteboard(), Self.e1Output)
    }

    func testE3_SelectedPresetIsRememberedAcrossRelaunch() throws {
        try requireIdiom(.phone)
        let app = XCUIApplication()
        launchWithClipboard(Self.e1Input, app: app)
        waitForValue(Self.e1Output, of: element("output", in: app))
        selectPreset("ruby héritée", app: app)
        capture("E3-iphone-preset-changed")

        XCUIDevice.shared.press(.home)
        XCTAssertTrue(app.wait(for: .runningBackground, timeout: 10))
        app.terminate()
        UIPasteboard.general.string = "やまだ タロウ"
        app.launchArguments = []
        app.launch()
        allowPasteOrWaitForOutput(app: app)

        assertSelectedPreset("ruby héritée", app: app)
        waitForValue("ﾔﾏﾀﾞ ﾀﾛｳ", of: element("output", in: app))
        capture("E3-iphone-after-relaunch")
        XCTAssertEqual(readPasteboard(), "ﾔﾏﾀﾞ ﾀﾛｳ")
    }

    func testE4_ConvertButtonConvertsEditedInput() throws {
        try requireIdiom(.phone)
        let app = XCUIApplication()
        launchWithClipboard(Self.e1Input, app: app)
        waitForValue(Self.e1Output, of: element("output", in: app))

        replaceText(of: element("input", in: app), with: "ｶﾅ")
        capture("E4-iphone-typed")
        app.buttons["convertButton"].tap()

        waitForValue("カナ", of: element("output", in: app))
        capture("E4-iphone-after-convert")
        attachText("E4-iphone-keyboard", "keyboards.count after convert = \(app.keyboards.count)")
        XCTAssertEqual(readPasteboard(), "カナ")
    }

    func testE5_UserPresetSwapsHiraganaAndKatakana() throws {
        try requireIdiom(.phone)
        let app = XCUIApplication()
        launchWithEmptyClipboard(app: app)

        app.buttons["settingsButton"].tap()
        assertBuiltInPresetIsReadOnly("régularisation", app: app)
        createSwapPreset(named: "テスト", app: app)
        convertWithSwapPreset(named: "テスト", app: app)
        capture("E5-iphone-after-convert")
    }

    func testE6_ReturningWithOwnOutputDoesNotReconvert() throws {
        try requireIdiom(.phone)
        let app = XCUIApplication()
        launchWithEmptyClipboard(app: app)
        app.buttons["settingsButton"].tap()
        createSwapPreset(named: "テスト", app: app)
        convertWithSwapPreset(named: "テスト", app: app)

        goHomeAndReturn(app: app)
        let alertShown = allowPasteIfPrompted(timeout: 3)

        // 再変換が起きたかどうかは、続く input の assertion で検出する
        XCTAssertFalse(alertShown, "前提「自分の出力を読むときはペースト許可が出ない」が崩れた")
        XCTAssertEqual(element("input", in: app).value as? String, "ひらカタ")
        XCTAssertEqual(element("output", in: app).value as? String, "ヒラかた")
        capture("E6-iphone-after-return")
        XCTAssertEqual(readPasteboard(), "ヒラかた")
    }

    func testE7_OutputIsSelectableButNotEditable() throws {
        try requireIdiom(.phone)
        let app = XCUIApplication()
        launchWithClipboard(Self.e1Input, app: app)
        let output = element("output", in: app)
        waitForValue(Self.e1Output, of: output)

        output.press(forDuration: 1.2)
        let copy = menuItem(["コピー", "Copy"], app: app)
        XCTAssertTrue(copy.waitForExistence(timeout: 5), "結果欄の長押しでコピーが出ない")
        XCTAssertFalse(menuItem(["カット", "Cut"], app: app).exists, "結果欄にカットが出た（編集可能）")
        XCTAssertFalse(menuItem(["ペースト", "Paste"], app: app).exists, "結果欄にペーストが出た（編集可能）")
        capture("E7-iphone-long-press-menu")
        attachText("E7-iphone-hierarchy", app.debugDescription)

        attachText("E7-iphone-keyboard", "keyboards.count = \(app.keyboards.count)")
        XCTAssertEqual(output.value as? String, Self.e1Output)
    }

    func testE9_EmptyClipboardRelaunchKeepsFieldsEmpty() throws {
        try requireIdiom(.phone)
        let app = XCUIApplication()
        launchWithEmptyClipboard(app: app)

        app.terminate()
        UIPasteboard.general.items = []
        app.launchArguments = []
        app.launch()
        let alertShown = allowPasteIfPrompted(timeout: 3)

        XCTAssertFalse(alertShown, "空のクリップボードでペースト許可が出た")
        XCTAssertEqual(app.state, .runningForeground)
        let input = element("input", in: app)
        let output = element("output", in: app)
        XCTAssertTrue(input.waitForExistence(timeout: 5), "入力欄が無い")
        XCTAssertTrue(output.waitForExistence(timeout: 5), "結果欄が無い")
        XCTAssertEqual(input.value as? String ?? "", "")
        XCTAssertEqual(output.value as? String ?? "", "")
        capture("E9-iphone-after-relaunch")
        XCTAssertNil(readPasteboard())
    }

    func testE10_SwitchingPresetThenBackgroundKeepsOwnOutput() throws {
        try requireIdiom(.phone)
        let app = XCUIApplication()
        launchWithEmptyClipboard(app: app)

        replaceText(of: element("input", in: app), with: "ｶﾅ")
        app.buttons["convertButton"].tap()
        waitForValue("カナ", of: element("output", in: app))
        selectPreset("ruby héritée", app: app)

        goHomeAndReturn(app: app)
        let alertShown = allowPasteIfPrompted(timeout: 3)

        XCTAssertFalse(alertShown, "前提「自分の出力を読むときはペースト許可が出ない」が崩れた")
        XCTAssertEqual(element("input", in: app).value as? String, "ｶﾅ")
        XCTAssertEqual(element("output", in: app).value as? String, "カナ")
        capture("E10-iphone-after-return")
        XCTAssertEqual(readPasteboard(), "カナ")
    }

    // MARK: - E8（iPad）

    func testE8_iPadLaunchConvertsClipboardInBothOrientations() throws {
        try requireIdiom(.pad)
        let app = XCUIApplication()
        XCUIDevice.shared.orientation = .portrait
        launchWithClipboard(Self.e1Input, app: app)

        XCTAssertEqual(element("input", in: app).value as? String, Self.e1Input)
        assertSelectedPreset("régularisation", app: app)
        waitForValue(Self.e1Output, of: element("output", in: app))
        assertMainControlsVisible(app: app)
        capture("E8-ipad-portrait")

        XCUIDevice.shared.orientation = .landscapeLeft
        Thread.sleep(forTimeInterval: 1.5)
        assertMainControlsVisible(app: app)
        XCTAssertEqual(element("output", in: app).value as? String, Self.e1Output)
        capture("E8-ipad-landscape")
        XCUIDevice.shared.orientation = .portrait

        XCTAssertEqual(readPasteboard(), Self.e1Output)
    }

    // MARK: - 起動・前面化

    private func launchWithClipboard(_ text: String, app: XCUIApplication) {
        app.terminate()
        UIPasteboard.general.string = text
        app.launchArguments = ["-reguUITestReset"]
        app.launch()
        let alertShown = allowPasteOrWaitForOutput(app: app)
        attachText("paste-alert-on-launch", "alert shown = \(alertShown)")
    }

    private func launchWithEmptyClipboard(app: XCUIApplication) {
        app.terminate()
        UIPasteboard.general.items = []
        app.launchArguments = ["-reguUITestReset"]
        app.launch()
    }

    private func goHomeAndReturn(app: XCUIApplication) {
        XCUIDevice.shared.press(.home)
        XCTAssertTrue(app.wait(for: .runningBackground, timeout: 10))
        app.activate()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
    }

    // 起動直後に、ペースト許可アラートが出る（押して true）か、結果欄に値が入る（false）まで待つ
    @discardableResult
    private func allowPasteOrWaitForOutput(app: XCUIApplication, timeout: TimeInterval = 10) -> Bool {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let output = element("output", in: app)
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            for label in Self.allowPasteLabels {
                let button = springboard.buttons[label]
                if button.exists {
                    capture("paste-alert")
                    button.tap()
                    return true
                }
            }
            if let value = output.value as? String, !value.isEmpty { return false }
            Thread.sleep(forTimeInterval: 0.2)
        } while Date() < deadline
        return false
    }

    // ペースト許可アラートは springboard 側に出る。押したら true
    @discardableResult
    private func allowPasteIfPrompted(timeout: TimeInterval) -> Bool {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            for label in Self.allowPasteLabels {
                let button = springboard.buttons[label]
                if button.exists {
                    capture("paste-alert")
                    button.tap()
                    return true
                }
            }
            Thread.sleep(forTimeInterval: 0.3)
        } while Date() < deadline
        return false
    }

    // MARK: - クリップボード

    // ランナー自身の読み込みにもペースト許可が出うるので、読み込みは別スレッドで行い、その間アラートを見張る
    private func readPasteboard() -> String? {
        let box = PasteboardBox()
        DispatchQueue.global().async {
            box.finish(with: UIPasteboard.general.string)
        }
        let deadline = Date().addingTimeInterval(30)
        while !box.isFinished {
            allowPasteIfPrompted(timeout: 0)
            if Date() > deadline {
                XCTFail("クリップボードの読み込みが終わらない")
                return nil
            }
            Thread.sleep(forTimeInterval: 0.3)
        }
        attachText("pasteboard", box.value ?? "(nil)")
        return box.value
    }

    // MARK: - 画面操作

    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    private func menuItem(_ labels: [String], app: XCUIApplication) -> XCUIElement {
        let predicate = NSPredicate(format: "label IN %@", labels)
        return app.descendants(matching: .any).matching(predicate).firstMatch
    }

    private func selectPreset(_ name: String, app: XCUIApplication) {
        let picker = app.buttons["presetPicker"]
        picker.tap()
        let item = app.buttons[name].firstMatch
        // キーボードが出ていると最初のタップがキーボードを閉じるだけになることがあるので、メニューが開かなければもう一度押す
        if !item.waitForExistence(timeout: 2) { picker.tap() }
        XCTAssertTrue(item.waitForExistence(timeout: 5), "プリセットのメニューに \(name) が無い")
        item.tap()
        assertSelectedPreset(name, app: app)
    }

    // 右下を押してカーソルを末尾に置き、既存の文字を消してから打つ（中央を押すと先頭にカーソルが来ることがある）
    private func replaceText(of field: XCUIElement, with text: String) {
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.9)).tap()
        let current = field.value as? String ?? ""
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count + 2))
        field.typeText(text)
        XCTAssertEqual(field.value as? String, text)
    }

    // 歯車画面（プリセット一覧）が出ている前提。追加 → 名前 → hiragana を swap → 一覧へ戻って閉じる
    private func createSwapPreset(named name: String, app: XCUIApplication) {
        app.buttons["addPresetButton"].tap()
        let nameField = app.textFields["presetNameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        replaceText(of: nameField, with: name)

        app.buttons["presetField.hiragana"].firstMatch.tap()
        let swap = app.buttons["ひらがな↔カタカナ"].firstMatch
        XCTAssertTrue(swap.waitForExistence(timeout: 5), "les hiraganas のメニューが出ない")
        swap.tap()
        capture("E5-iphone-user-preset-edited")

        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 5), "一覧に \(name) が無い")
        capture("E5-iphone-preset-list")
        app.buttons["closePresetsButton"].tap()
    }

    private func convertWithSwapPreset(named name: String, app: XCUIApplication) {
        selectPreset(name, app: app)
        replaceText(of: element("input", in: app), with: "ひらカタ")
        app.buttons["convertButton"].tap()
        waitForValue("ヒラかた", of: element("output", in: app))
    }

    // MARK: - 確認

    private func requireIdiom(_ idiom: UIUserInterfaceIdiom) throws {
        guard UIDevice.current.userInterfaceIdiom == idiom else {
            throw XCTSkip("この項目は \(idiom == .pad ? "iPad" : "iPhone") で行う")
        }
    }

    private func waitForValue(_ expected: String, of element: XCUIElement, timeout: TimeInterval = 10) {
        let predicate = NSPredicate(format: "value == %@", expected)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        XCTAssertEqual(result, .completed, "値が \(expected) にならない（実際: \(String(describing: element.value))）")
    }

    // Picker(.menu) の label は「プリセット、<選択中の名前>」になる
    private func assertSelectedPreset(_ name: String, app: XCUIApplication) {
        let picker = app.buttons["presetPicker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        XCTAssertEqual(picker.label, "プリセット、\(name)")
    }

    // 歯車画面で既定プリセットを開き、名前欄が無く設定の Picker が無効であること・削除の操作が無いことを確かめて一覧に戻る
    private func assertBuiltInPresetIsReadOnly(_ name: String, app: XCUIApplication) {
        let row = app.collectionViews.staticTexts[name].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))

        row.tap()
        let hiragana = app.buttons["presetField.hiragana"].firstMatch
        XCTAssertTrue(hiragana.waitForExistence(timeout: 5))
        XCTAssertFalse(hiragana.isEnabled, "既定プリセットの設定が編集できる")
        XCTAssertFalse(app.textFields["presetNameField"].exists, "既定プリセットの名前が編集できる")
        capture("E5-iphone-builtin-editor")
        app.navigationBars.buttons.element(boundBy: 0).tap()

        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.press(forDuration: 1.2)
        XCTAssertTrue(menuItem(["複製"], app: app).waitForExistence(timeout: 5), "既定プリセットのメニューに複製が無い")
        XCTAssertFalse(menuItem(["削除", "Delete"], app: app).exists, "既定プリセットのメニューに削除がある")
        capture("E5-iphone-builtin-context-menu")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.97)).tap()
        // 左スワイプ（削除）の有無は、払う操作が行のタップとして扱われ編集画面へ進むため見ない（既定の削除防止は単体テスト S5）
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["addPresetButton"].waitForExistence(timeout: 5), "一覧に戻っていない")
    }

    private func assertMainControlsVisible(app: XCUIApplication) {
        let window = app.windows.firstMatch.frame
        for identifier in ["input", "output", "presetPicker", "convertButton", "settingsButton"] {
            let target = element(identifier, in: app)
            XCTAssertTrue(target.isHittable, "\(identifier) が押せない位置にある")
            XCTAssertTrue(window.contains(target.frame), "\(identifier) が画面外にはみ出している")
        }
    }

    // MARK: - 証跡

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func attachText(_ name: String, _ text: String) {
        let attachment = XCTAttachment(string: text)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

// 別スレッドで読んだクリップボードの値の受け渡し用
private final class PasteboardBox: @unchecked Sendable {
    private let lock = NSLock()
    private var storedValue: String?
    private var finished = false

    var isFinished: Bool {
        lock.withLock { finished }
    }

    var value: String? {
        lock.withLock { storedValue }
    }

    func finish(with value: String?) {
        lock.withLock {
            storedValue = value
            finished = true
        }
    }
}
