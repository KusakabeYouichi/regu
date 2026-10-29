import ReguCore
import SwiftUI

// 縦長: 上に入力カード(編集可) / 中にプリセット・変換・設定の行 / 下に結果カード(読み取り専用・選択可)。
// 横長(画面の幅 > 高さ。機種では分けない): 左に入力カード / 中央にプリセット・変換・設定の列 / 右に結果カード
public struct MainView: View {
    // 「コピーしました」を出しておく時間
    private static let badgeDuration: Duration = .seconds(1.5)
    // 見出しと本文の間。全選択したときの上側の選択ハンドルが見出しに掛からない幅
    private static let headerSpacing: CGFloat = 12
    // 横長のときの中央の列の幅
    private static let controlColumnWidth: CGFloat = 150
    // 中央の列がこの高さに満たないとき(横長でキーボード表示中など)は、タイルを縮めてキャプションを隠す
    private static let regularColumnMinHeight: CGFloat = 200

    @Bindable private var session: ConversionSession
    @State private var isShowingPresets = false
    @State private var isShowingCopiedBadge = false
    @State private var badgeHideTask: Task<Void, Never>?
    @FocusState private var isInputFocused: Bool
    @State private var isLandscape = false
    @State private var controlColumnHeight: CGFloat = .infinity
    @Environment(\.scenePhase) private var scenePhase

    public init(session: ConversionSession) {
        self.session = session
    }

    // 縦横の切り替えで入力欄・結果欄を作り直さないよう(フォーカス・全選択を保つ)、AnyLayout で並べ方だけ替える
    public var body: some View {
        let layout = isLandscape ? AnyLayout(HStackLayout(spacing: 16)) : AnyLayout(VStackLayout(spacing: 16))
        layout {
            inputCard
            if isLandscape {
                controlColumn
            } else {
                controlRow
            }
            outputCard
        }
        .padding(.horizontal)
        .padding(.vertical, isLandscape && isInputFocused ? 8 : 16)
        // 縦横はキーボードを除いた領域で決める(キーボードで高さが減っても縦長のまま扱う)
        .background {
            Color.clear
                .ignoresSafeArea(.keyboard)
                .onGeometryChange(for: Bool.self) { proxy in
                    proxy.size.width > proxy.size.height
                } action: { newValue in
                    isLandscape = newValue
                }
        }
        .background(Theme.paper)
        .tint(Theme.accent)
        .sheet(isPresented: $isShowingPresets) {
            PresetListView(store: session.store)
        }
        // selectAllToken はクリップボードへ書いた直後に必ず増える。起動時の自動変換が初回描画より先に済んでいたら onAppear で出す
        .onChange(of: session.selectAllToken) {
            showCopiedBadge()
        }
        .onAppear {
            if session.selectAllToken != 0 {
                showCopiedBadge()
            }
        }
        // 背面にいる間に残り時間が止まり、戻ったときに古い表示が残らないようにする
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                hideCopiedBadge()
            }
        }
    }

    // キーボード表示中・横長はカードの最小高さを下げ、操作行(列)が隠れないようにする
    private var inputCard: some View {
        VStack(alignment: .leading, spacing: Self.headerSpacing) {
            cardHeader("entrée")
            TextEditor(text: $session.input)
                .font(.body)
                .scrollContentBackground(.hidden)
                .focused($isInputFocused)
                .overlay(alignment: .topLeading) {
                    if session.input.isEmpty {
                        Text("ここにペースト")
                            .font(.body)
                            .foregroundStyle(.tertiary)
                            .padding(.top, 8)
                            .padding(.leading, 5)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                }
                .accessibilityLabel("入力")
                .accessibilityIdentifier("input")
        }
        .padding(12)
        .frame(minHeight: isLandscape ? 56 : (isInputFocused ? 72 : 160), maxHeight: .infinity)
        .modifier(CardBackground())
    }

    private var outputCard: some View {
        VStack(alignment: .leading, spacing: Self.headerSpacing) {
            cardHeader("résultat")
            ReadOnlySelectableTextView(text: session.output, selectAllToken: session.selectAllToken)
                .accessibilityLabel("変換結果")
                .accessibilityIdentifier("output")
        }
        .padding(12)
        .frame(minHeight: isLandscape ? 56 : (isInputFocused ? 56 : 120), maxHeight: .infinity)
        .modifier(CardBackground())
        // 見出しに重ならないよう、右下の角に出す
        .overlay(alignment: .bottomTrailing) {
            if isShowingCopiedBadge {
                CopiedBadge()
                    .padding(10)
                    .transition(.opacity)
            }
        }
    }

    // 見出しは見た目だけ。VoiceOver には入力欄・結果欄の label で読ませる
    private func cardHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.medium))
            .tracking(0.8)
            .foregroundStyle(.secondary)
            .padding(.leading, 5)
            .accessibilityHidden(true)
    }

    // 左右を同じ幅にして、変換ボタンを常に中央に置く。文字が大きくても 1 行に収める
    // (チップの名前は入りきらなければ 0.7 倍まで縮め、それでも入らなければ末尾を省略する)
    private var controlRow: some View {
        HStack(spacing: 12) {
            presetChip(height: 44)
                .frame(maxWidth: .infinity, alignment: .leading)
            convertButton(tileSize: TileConvertButton.regularTileSize, showsCaption: true)
            settingsButton(size: 44)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    // 横長の中央の列。上からチップ・変換ボタン・設定。高さが足りなければ間を詰めタイルを小さくして、変換ボタンを必ず見せる(押せる大きさ 44pt は保つ)
    private var controlColumn: some View {
        let isCompact = controlColumnHeight < Self.regularColumnMinHeight
        return VStack(spacing: isCompact ? 4 : 12) {
            presetChip(height: 44)
            Spacer(minLength: 0)
            convertButton(
                tileSize: isCompact ? TileConvertButton.compactTileSize : TileConvertButton.regularTileSize,
                showsCaption: !isCompact
            )
            Spacer(minLength: 0)
            settingsButton(size: 44)
        }
        .frame(width: Self.controlColumnWidth)
        .frame(maxHeight: .infinity)
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.height
        } action: { newValue in
            controlColumnHeight = newValue
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    private func convertButton(tileSize: CGFloat, showsCaption: Bool) -> some View {
        TileConvertButton(tileSize: tileSize, showsCaption: showsCaption) {
            session.convertTapped()
        }
        .accessibilityIdentifier("convertButton")
    }

    private func presetChip(height: CGFloat) -> some View {
        Menu {
            Picker("プリセット", selection: presetSelection) {
                Section {
                    ForEach(Preset.builtIns) { preset in
                        Text(session.store.displayName(for: preset)).tag(preset.id)
                    }
                }
                if !session.store.userPresets.isEmpty {
                    Section {
                        ForEach(session.store.userPresets) { preset in
                            Text(session.store.displayName(for: preset)).tag(preset.id)
                        }
                    }
                }
            }
            .pickerStyle(.inline)
        } label: {
            HStack(spacing: 4) {
                Text(session.store.displayName(for: session.store.selectedPreset))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .truncationMode(.tail)
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Theme.accent)
            .padding(.horizontal, 12)
            .frame(minHeight: height)
            .modifier(CapsuleBackground())
        }
        .menuOrder(.fixed)
        .accessibilityLabel("プリセット")
        .accessibilityValue(session.store.displayName(for: session.store.selectedPreset))
        .accessibilityIdentifier("presetPicker")
    }

    private func settingsButton(size: CGFloat) -> some View {
        Button {
            isShowingPresets = true
        } label: {
            Image(systemName: "gearshape")
                .font(.body.weight(.medium))
                .foregroundStyle(Color.secondary)
                .frame(width: size, height: size)
                .modifier(CapsuleBackground())
        }
        .accessibilityLabel("プリセットの設定")
        .accessibilityIdentifier("settingsButton")
    }

    private var presetSelection: Binding<UUID> {
        Binding(
            get: { session.selectedPresetID },
            set: { session.select($0) }
        )
    }

    // 表示は常に 1 枚。表示中に再び呼ばれたら残り時間を数え直す
    private func showCopiedBadge() {
        badgeHideTask?.cancel()
        withAnimation(.easeOut(duration: 0.2)) {
            isShowingCopiedBadge = true
        }
        AccessibilityNotification.Announcement("コピーしました").post()
        badgeHideTask = Task {
            try? await Task.sleep(for: Self.badgeDuration)
            guard !Task.isCancelled else {
                return
            }
            withAnimation(.easeIn(duration: 0.3)) {
                isShowingCopiedBadge = false
            }
        }
    }

    private func hideCopiedBadge() {
        badgeHideTask?.cancel()
        badgeHideTask = nil
        isShowingCopiedBadge = false
    }
}

// チップと設定ボタンの下地。カードと同じ地に、ライトだけ薄い影
private struct CapsuleBackground: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background {
                Capsule()
                    .fill(Theme.card)
                    .shadow(color: .black.opacity(colorScheme == .dark ? 0 : 0.07), radius: 6, y: 2)
            }
    }
}
