import XCTest

// E2E 計画(c01-e2e-plan.md)の E1–E9 を XCUITest で行う。
// クリップボードはテストランナーから UIPasteboard.general で読み書きする(simctl pbcopy の代わり)。
// 各テストは -reguUITestReset 付きの起動から始め、前のテストの状態に依存しない。
// E11〜E14 は c02(メイン画面の刷新)で足した「コピーしました」の表示・横長の配置・プリセットのチップ
// E15 は c03(ビルトインの別名)
@MainActor
final class ReguE2EUITests: XCTestCase {
    private static let allowPasteLabels = ["ペーストを許可", "Allow Paste"]
    private static let e1Input = "ＡＢＣ１２３　ｶﾀｶﾅ「x」㎜"
    private static let e1Output = "ABC123 カタカナ『x』mm"
    // チップの幅に必ず収まらない長さのユーザープリセット名
    private static let longPresetName = "ふりがな用(銀行・カード会社・証券口座)"
    private static let regularisationRow = "presetRow.6F1C2A10-0000-4000-8000-000000000001"

    // MARK: - E1–E7, E9(iPhone)

    func testE1_LaunchConvertsClipboardWithDefaultPreset() throws {
        try requireIdiom(.phone)
        let app = XCUIApplication()
        launchWithClipboard(Self.e1Input, app: app)
        // 表示は 1.5 秒だけなので、他の確認より先に見る
        XCTAssertTrue(element("copiedBadge", in: app).waitForExistence(timeout: 5), "起動時の自動変換で「コピーしました」が出ない")
        capture("E1-iphone-copied-badge")

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
        assertCopiedBadgeDoesNotAppear(app: app)
        let alertShown = allowPasteIfPrompted(timeout: 3)
        XCTAssertFalse(element("copiedBadge", in: app).exists, "コピーしていないのに「コピーしました」が出た")

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
        assertConvertButtonHittableWithKeyboard(app: app)
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
        assertCopiedBadgeDoesNotAppear(app: app)
        let alertShown = allowPasteIfPrompted(timeout: 3)
        XCTAssertFalse(element("copiedBadge", in: app).exists, "コピーしていないのに「コピーしました」が出た")

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
        XCTAssertFalse(menuItem(["カット", "Cut"], app: app).exists, "結果欄にカットが出た(編集可能)")
        XCTAssertFalse(menuItem(["ペースト", "Paste"], app: app).exists, "結果欄にペーストが出た(編集可能)")
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
        assertConvertButtonHittableWithKeyboard(app: app)
        app.buttons["convertButton"].tap()
        waitForValue("カナ", of: element("output", in: app))
        selectPreset("ruby héritée", app: app)

        goHomeAndReturn(app: app)
        assertCopiedBadgeDoesNotAppear(app: app)
        let alertShown = allowPasteIfPrompted(timeout: 3)
        XCTAssertFalse(element("copiedBadge", in: app).exists, "コピーしていないのに「コピーしました」が出た")

        XCTAssertFalse(alertShown, "前提「自分の出力を読むときはペースト許可が出ない」が崩れた")
        XCTAssertEqual(element("input", in: app).value as? String, "ｶﾅ")
        XCTAssertEqual(element("output", in: app).value as? String, "カナ")
        capture("E10-iphone-after-return")
        XCTAssertEqual(readPasteboard(), "カナ")
    }

    func testE11_CopiedBadgeAppearsOnceAndDisappears() throws {
        try requireIdiom(.phone)
        let app = XCUIApplication()
        launchWithEmptyClipboard(app: app)
        let badge = element("copiedBadge", in: app)
        XCTAssertFalse(badge.exists, "コピーしていないのに「コピーしました」が出ている")

        replaceText(of: element("input", in: app), with: "ｶﾅ")
        app.buttons["convertButton"].tap()
        XCTAssertTrue(badge.waitForExistence(timeout: 2), "変換ボタンの直後に「コピーしました」が出ない")

        // 表示中に押し直す。数え直さなければ、1 度目の表示から 1.5 秒(2 度目の押下からはそれより短い時間)で消える。
        // 1 度目の表示の時刻は検出の遅れで正確に取れないため、待たずに押し直し、2 度目の押下からの経過だけを見る
        XCTAssertTrue(badge.exists, "2 度目を押す前に「コピーしました」が消えた")
        let secondTap = Date()
        app.buttons["convertButton"].tap()
        capture("E11-iphone-copied-badge")
        let badges = app.descendants(matching: .any).matching(identifier: "copiedBadge")
        XCTAssertEqual(badges.count, 1, "表示中にもう一度押すと「コピーしました」が増えた")

        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: badge)
        XCTAssertEqual(XCTWaiter.wait(for: [gone], timeout: 5), .completed, "「コピーしました」が消えない")
        XCTAssertGreaterThanOrEqual(Date().timeIntervalSince(secondTap), 1.2, "再押下で表示時間が数え直されていない")
        XCTAssertEqual(readPasteboard(), "カナ")
    }

    // 表示中にホームへ出て戻ったら、残り時間に関係なく消えている
    func testE14_CopiedBadgeIsHiddenAfterReturningFromHome() throws {
        try requireIdiom(.phone)
        let app = XCUIApplication()
        launchWithEmptyClipboard(app: app)
        replaceText(of: element("input", in: app), with: "ｶﾅ")
        app.buttons["convertButton"].tap()
        XCTAssertTrue(element("copiedBadge", in: app).waitForExistence(timeout: 2), "変換ボタンの直後に「コピーしました」が出ない")

        goHomeAndReturn(app: app)

        XCTAssertFalse(element("copiedBadge", in: app).exists, "ホームから戻った後も「コピーしました」が残っている")
        capture("E14-iphone-after-return")
    }

    // 横長でキーボードが出ていても、両カードと中央の列(チップ・変換ボタン・設定)が見切れずに押せる
    func testE12_LandscapeKeepsCardsAndConvertButtonUsableWithKeyboard() throws {
        try checkLandscapeWithKeyboard(extraArguments: [], captureName: "E12-iphone-landscape-keyboard")
    }

    // 文字サイズが大きくても、横長・キーボード表示中に中央の列が見切れない(キャプションが伸びても列が縮む)
    func testE12b_LandscapeColumnFitsWithLargerTextAndKeyboard() throws {
        try checkLandscapeWithKeyboard(
            extraArguments: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"],
            captureName: "E12b-iphone-landscape-keyboard-large-text"
        )
    }

    private func checkLandscapeWithKeyboard(extraArguments: [String], captureName: String) throws {
        try requireIdiom(.phone)
        addTeardownBlock {
            XCUIDevice.shared.orientation = .portrait
        }
        let app = XCUIApplication()
        launchWithEmptyClipboard(app: app, extraArguments: extraArguments)
        XCUIDevice.shared.orientation = .landscapeLeft
        waitForLandscape(app: app)

        replaceText(of: element("input", in: app), with: "ｶﾅ")
        let keyboard = app.keyboards.firstMatch
        XCTAssertTrue(keyboard.waitForExistence(timeout: 5), "キーボードが出ていない")
        capture(captureName)
        for identifier in ["input", "output", "convertButton", "presetPicker", "settingsButton"] {
            XCTAssertTrue(element(identifier, in: app).isHittable, "横長・キーボード表示中に \(identifier) が押せない")
        }
        // isHittable は一部が見切れていても真になるため、枠の全体が画面の内側・キーボードより上にあることを見る
        let window = app.windows.firstMatch.frame
        for identifier in ["presetPicker", "convertButton", "settingsButton"] {
            let frame = element(identifier, in: app).frame
            XCTAssertGreaterThanOrEqual(frame.minY, window.minY, "\(identifier) の上端が画面の外にある(\(frame))")
            XCTAssertLessThanOrEqual(frame.maxY, keyboard.frame.minY, "\(identifier) の下端がキーボードに隠れている(\(frame)、キーボード \(keyboard.frame))")
        }

        app.buttons["convertButton"].tap()
        XCTAssertTrue(element("copiedBadge", in: app).waitForExistence(timeout: 2), "変換ボタンの直後に「コピーしました」が出ない")
        waitForValue("カナ", of: element("output", in: app))
        capture("\(captureName)-after-convert")
        XCUIDevice.shared.orientation = .portrait
        XCTAssertEqual(readPasteboard(), "カナ")
    }

    // 長い名前でもチップは 1 行のまま左半分に収まり、中央の変換ボタンに重ならない
    func testE13_PresetChipFitsLongNamesBesideCenteredConvertButton() throws {
        try requireIdiom(.phone)
        let app = XCUIApplication()
        launchWithEmptyClipboard(app: app)

        selectPreset("Adresse héritée", app: app)
        assertChipBesideCenteredConvertButton(app: app)
        replaceText(of: element("input", in: app), with: "ＡＢＣ１２３　ｶﾀｶﾅ")
        app.buttons["convertButton"].tap()
        XCTAssertTrue(element("copiedBadge", in: app).waitForExistence(timeout: 2), "変換ボタンの直後に「コピーしました」が出ない")
        capture("E13-iphone-adresse-heritee")

        app.buttons["settingsButton"].tap()
        createPreset(named: Self.longPresetName, app: app)
        selectPreset(Self.longPresetName, app: app)
        assertChipBesideCenteredConvertButton(app: app)
        capture("E13-iphone-long-user-preset")
    }

    // ビルトインに別名を付けるとチップ・メニュー・一覧に出て、消すと元の名前に戻る。
    // 縮小・省略そのものは XCUITest から見えない(label は全文のまま)ので、表示文字列と同じ行の開き直しで確かめる
    func testE15_BuiltInAliasIsShownAndCanBeRemoved() throws {
        try requireIdiom(.phone)
        let app = XCUIApplication()
        launchWithEmptyClipboard(app: app)

        app.buttons["settingsButton"].tap()
        openPresetRow(Self.regularisationRow, app: app)
        let aliasField = app.textFields["presetAliasField"]
        XCTAssertTrue(aliasField.waitForExistence(timeout: 5), "ビルトインの編集画面に別名の欄が無い")
        XCTAssertTrue(app.staticTexts["régularisation"].exists, "編集画面に本当の名前が無い")
        aliasField.tap()
        aliasField.typeText("正規化(ふつう)")
        capture("E15-iphone-alias-editor")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.staticTexts["régularisation - 正規化(ふつう)"].waitForExistence(timeout: 5), "一覧に「本当の名前 - 別名」が出ない")
        capture("E15-iphone-alias-list")
        app.buttons["closePresetsButton"].tap()

        assertSelectedPreset("正規化(ふつう)", app: app)
        selectPreset("正規化(ふつう)", app: app)
        capture("E15-iphone-alias-chip")

        app.buttons["settingsButton"].tap()
        openPresetRow(Self.regularisationRow, app: app)
        XCTAssertTrue(aliasField.waitForExistence(timeout: 5))
        XCTAssertEqual(aliasField.value as? String, "正規化(ふつう)")
        // 別名の欄は右寄せなので、タップ位置しだいでカーソルが末尾に来ない。全選択してから消す
        aliasField.tap()
        aliasField.press(forDuration: 1.0)
        let selectAll = menuItem(["すべてを選択", "全選択", "Select All"], app: app)
        XCTAssertTrue(selectAll.waitForExistence(timeout: 5), "別名の欄で全選択が出ない")
        selectAll.tap()
        aliasField.typeText(XCUIKeyboardKey.delete.rawValue)
        XCTAssertNotEqual(aliasField.value as? String, "正規化(ふつう)", "別名の欄から別名が消えない")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.staticTexts["régularisation"].waitForExistence(timeout: 5), "別名を消しても一覧が元の名前に戻らない")
        XCTAssertFalse(app.staticTexts["régularisation - 正規化(ふつう)"].exists, "別名を消しても一覧に別名が残っている")
        app.buttons["closePresetsButton"].tap()

        assertSelectedPreset("régularisation", app: app)
        selectPreset("régularisation", app: app)
    }

    // + は「ユーザー設定」の見出しの隣にあり、新しいプリセットは名前も設定も変えずに戻ると(変えて元に戻しても)一覧に残らない。
    // 名前を変えたものは残る。編集画面の名前の見出しは nom
    func testE16_UntouchedNewPresetIsNotAdded() throws {
        try requireIdiom(.phone)
        let app = XCUIApplication()
        launchWithEmptyClipboard(app: app)
        app.buttons["settingsButton"].tap()
        let addButton = app.buttons["addPresetButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "一覧に + が無い")
        XCTAssertFalse(app.navigationBars.buttons["addPresetButton"].exists, "+ がツールバーに残っている")
        let header = app.staticTexts["ユーザー設定"]
        XCTAssertEqual(addButton.frame.midY, header.frame.midY, accuracy: 22, "+ が「ユーザー設定」の見出しの行に無い")
        capture("E16-iphone-add-button-in-header")

        addButton.tap()
        XCTAssertTrue(app.textFields["presetNameField"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["nom"].exists, "編集画面の見出しが nom でない")
        capture("E16-iphone-new-preset-editor")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "一覧に戻っていない")
        XCTAssertFalse(app.staticTexts["新しいプリセット"].exists, "何も変えずに戻ったのに追加されている")

        addButton.tap()
        app.buttons["presetField.hiragana"].firstMatch.tap()
        let swap = app.buttons["ひらがな↔カタカナ"].firstMatch
        XCTAssertTrue(swap.waitForExistence(timeout: 5))
        swap.tap()
        app.buttons["presetField.hiragana"].firstMatch.tap()
        let preserve = app.buttons["preserve"].firstMatch
        XCTAssertTrue(preserve.waitForExistence(timeout: 5))
        preserve.tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "一覧に戻っていない")
        XCTAssertFalse(app.staticTexts["新しいプリセット"].exists, "設定を変えて元に戻したのに追加されている")

        // 編集画面を開いたまま一覧ごと下へ払って閉じても残らない
        addButton.tap()
        XCTAssertTrue(app.textFields["presetNameField"].waitForExistence(timeout: 5))
        let top = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1))
        top.press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95)))
        let sheetClosed = NSPredicate(format: "exists == false")
        let nameFieldGone = XCTNSPredicateExpectation(predicate: sheetClosed, object: app.textFields["presetNameField"])
        XCTAssertEqual(XCTWaiter().wait(for: [nameFieldGone], timeout: 5), .completed, "一覧が閉じていない")
        capture("E16-iphone-sheet-dismissed")
        app.buttons["settingsButton"].tap()
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["新しいプリセット"].exists, "編集中に一覧ごと閉じたのに追加されている")
        app.buttons["closePresetsButton"].tap()
        app.buttons["settingsButton"].tap()

        createPreset(named: "名前だけ", app: app)
        app.buttons["settingsButton"].tap()
        XCTAssertTrue(app.staticTexts["名前だけ"].waitForExistence(timeout: 5), "名前を変えたプリセットが残っていない")
        capture("E16-iphone-list-after")
        app.buttons["closePresetsButton"].tap()
    }

    // 横長でキーボード表示中にプリセットのチップを押しても落ちず、メニューから選べる
    // (キーボードが閉じて中央の列が詰めた形から戻る途中にメニューが開く)
    func testE17_PresetMenuOpensInLandscapeWithKeyboard() throws {
        try requireIdiom(.phone)
        addTeardownBlock {
            XCUIDevice.shared.orientation = .portrait
        }
        let app = XCUIApplication()
        launchWithEmptyClipboard(app: app)
        XCUIDevice.shared.orientation = .landscapeLeft
        waitForLandscape(app: app)
        replaceText(of: element("input", in: app), with: "ｶﾅ")
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5), "キーボードが出ていない")

        selectPreset("Adresse héritée", app: app)
        XCTAssertEqual(app.state, .runningForeground, "チップを押した後にアプリが前面で動いていない")
        capture("E17-iphone-landscape-after-menu")
        selectPreset("régularisation", app: app)
    }

    // MARK: - E8(iPad)

    func testE8_iPadLaunchConvertsClipboardInBothOrientations() throws {
        try requireIdiom(.pad)
        let app = XCUIApplication()
        XCUIDevice.shared.orientation = .portrait
        launchWithClipboard(Self.e1Input, app: app)
        XCTAssertTrue(element("copiedBadge", in: app).waitForExistence(timeout: 5), "起動時の自動変換で「コピーしました」が出ない")
        capture("E8-ipad-copied-badge")

        XCTAssertEqual(element("input", in: app).value as? String, Self.e1Input)
        assertSelectedPreset("régularisation", app: app)
        waitForValue(Self.e1Output, of: element("output", in: app))
        assertMainControlsVisible(app: app)
        capture("E8-ipad-portrait")

        XCUIDevice.shared.orientation = .landscapeLeft
        waitForLandscape(app: app)
        assertMainControlsVisible(app: app)
        XCTAssertEqual(element("output", in: app).value as? String, Self.e1Output)
        capture("E8-ipad-landscape")
        element("input", in: app).tap()
        // ソフトウェアキーボードが出ない環境(ハードウェアキーボード接続)では、この確認だけを最後に skip として残す
        let keyboardShown = app.keyboards.firstMatch.waitForExistence(timeout: 5)
        if keyboardShown {
            XCTAssertTrue(app.buttons["convertButton"].isHittable, "横長・キーボード表示中に変換ボタンが押せない")
            capture("E8-ipad-landscape-keyboard")
        }
        XCUIDevice.shared.orientation = .portrait

        XCTAssertEqual(readPasteboard(), Self.e1Output)
        if !keyboardShown {
            throw XCTSkip("横長でソフトウェアキーボードが出なかったため、キーボード表示中の変換ボタンの確認は行っていない(ハードウェアキーボード接続の可能性)")
        }
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

    private func launchWithEmptyClipboard(app: XCUIApplication, extraArguments: [String] = []) {
        app.terminate()
        UIPasteboard.general.items = []
        app.launchArguments = ["-reguUITestReset"] + extraArguments
        app.launch()
    }

    private func goHomeAndReturn(app: XCUIApplication) {
        XCUIDevice.shared.press(.home)
        XCTAssertTrue(app.wait(for: .runningBackground, timeout: 10))
        app.activate()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
    }

    // 起動直後に、ペースト許可アラートが出る(押して true)か、結果欄に値が入る(false)まで待つ
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

    // 歯車画面(プリセット一覧)が出ている前提。名前に依存せず、行の識別子で編集画面を開く
    private func openPresetRow(_ identifier: String, app: XCUIApplication) {
        let row = element(identifier, in: app)
        XCTAssertTrue(row.waitForExistence(timeout: 5), "一覧に \(identifier) の行が無い")
        row.tap()
    }

    // 右下を押してカーソルを末尾に置き、既存の文字を消してから打つ(中央を押すと先頭にカーソルが来ることがある)
    private func replaceText(of field: XCUIElement, with text: String) {
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.9)).tap()
        let current = field.value as? String ?? ""
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count + 2))
        field.typeText(text)
        XCTAssertEqual(field.value as? String, text)
    }

    // 歯車画面(プリセット一覧)が出ている前提。追加 → 名前 → hiragana を swap → 一覧へ戻って閉じる
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

    // 歯車画面(プリセット一覧)が出ている前提。追加 → 名前だけ付けて一覧へ戻って閉じる(設定は既定のまま)
    private func createPreset(named name: String, app: XCUIApplication) {
        app.buttons["addPresetButton"].tap()
        let nameField = app.textFields["presetNameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        replaceText(of: nameField, with: name)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 5), "一覧に \(name) が無い")
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
        XCTAssertEqual(result, .completed, "値が \(expected) にならない(実際: \(String(describing: element.value)))")
    }

    // プリセットのチップ(Menu)は label「プリセット」、value に選択中の名前を持つ
    private func assertSelectedPreset(_ name: String, app: XCUIApplication) {
        let picker = app.buttons["presetPicker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        XCTAssertEqual(picker.label, "プリセット")
        XCTAssertEqual(picker.value as? String, name)
    }

    // チップは画面内で変換ボタンの左に収まり、変換ボタンは画面の中央にある。
    // 文字の縮小・末尾の省略そのものは XCUITest からは見えない(label は全文のまま)ので、枠の位置だけを見る
    private func assertChipBesideCenteredConvertButton(app: XCUIApplication) {
        let chip = app.buttons["presetPicker"].frame
        let convert = app.buttons["convertButton"].frame
        let window = app.windows.firstMatch.frame
        XCTAssertTrue(window.contains(chip), "チップが画面外にはみ出している(\(chip))")
        XCTAssertFalse(chip.intersects(convert), "チップが変換ボタンに重なっている")
        XCTAssertLessThanOrEqual(chip.maxX, convert.minX, "チップが変換ボタンの左にない")
        XCTAssertEqual(convert.midX, window.midX, accuracy: 1, "変換ボタンが中央にない")
    }

    // 回転は非同期なので、アプリの window が横長になるまで待つ
    private func waitForLandscape(app: XCUIApplication) {
        let isLandscape = NSPredicate { object, _ in
            guard let window = object as? XCUIElement else {
                return false
            }
            return window.frame.width > window.frame.height
        }
        let expectation = XCTNSPredicateExpectation(predicate: isLandscape, object: app.windows.firstMatch)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 10), .completed, "横長に回っていない(\(app.windows.firstMatch.frame))")
    }

    // コピーしていないときは「コピーしました」が出ない(出るなら前面化の直後なので、その間だけ見張る)
    private func assertCopiedBadgeDoesNotAppear(app: XCUIApplication) {
        XCTAssertFalse(element("copiedBadge", in: app).waitForExistence(timeout: 2), "コピーしていないのに「コピーしました」が出た")
    }

    // キーボード表示中でも変換ボタンが隠れず押せる
    private func assertConvertButtonHittableWithKeyboard(app: XCUIApplication) {
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5), "キーボードが出ていない")
        XCTAssertTrue(app.buttons["convertButton"].isHittable, "キーボード表示中に変換ボタンが押せない")
    }

    // 歯車画面でビルトインのプリセットを開き、名前欄が無く設定の Picker が無効であること・削除の操作が無いことを確かめて一覧に戻る
    private func assertBuiltInPresetIsReadOnly(_ name: String, app: XCUIApplication) {
        let row = app.collectionViews.staticTexts[name].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))

        row.tap()
        let hiragana = app.buttons["presetField.hiragana"].firstMatch
        XCTAssertTrue(hiragana.waitForExistence(timeout: 5))
        XCTAssertFalse(hiragana.isEnabled, "ビルトインのプリセットの設定が編集できる")
        XCTAssertFalse(app.textFields["presetNameField"].exists, "ビルトインのプリセットの名前が編集できる")
        capture("E5-iphone-builtin-editor")
        app.navigationBars.buttons.element(boundBy: 0).tap()

        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.press(forDuration: 1.2)
        XCTAssertTrue(menuItem(["複製"], app: app).waitForExistence(timeout: 5), "ビルトインのプリセットのメニューに複製が無い")
        XCTAssertFalse(menuItem(["削除", "Delete"], app: app).exists, "ビルトインのプリセットのメニューに削除がある")
        capture("E5-iphone-builtin-context-menu")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.97)).tap()
        // 左スワイプ(削除)の有無は、払う操作が行のタップとして扱われ編集画面へ進むため見ない(ビルトインの削除防止は単体テスト S5)
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
