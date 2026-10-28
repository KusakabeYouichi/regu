import ReguCore
import SwiftUI

// 上: 入力（編集可） / 中: プリセット・変換・設定 / 下: 結果（読み取り専用・選択可）
public struct MainView: View {
    @Bindable private var session: ConversionSession
    @State private var isShowingPresets = false

    public init(session: ConversionSession) {
        self.session = session
    }

    public var body: some View {
        VStack(spacing: 12) {
            TextEditor(text: $session.input)
                .font(.body)
                .frame(minHeight: 160, maxHeight: .infinity)
                .framed()
                .accessibilityLabel("入力")
                .accessibilityIdentifier("input")
            controlRow
            ReadOnlySelectableTextView(text: session.output, selectAllToken: session.selectAllToken)
                .frame(minHeight: 120, maxHeight: .infinity)
                .framed()
                .accessibilityLabel("変換結果")
                .accessibilityIdentifier("output")
        }
        .padding()
        .sheet(isPresented: $isShowingPresets) {
            PresetListView(store: session.store)
        }
    }

    private var controlRow: some View {
        HStack(spacing: 12) {
            Picker("プリセット", selection: presetSelection) {
                Section {
                    ForEach(Preset.builtIns) { preset in
                        Text(preset.name).tag(preset.id)
                    }
                }
                if !session.store.userPresets.isEmpty {
                    Section {
                        ForEach(session.store.userPresets) { preset in
                            Text(preset.name).tag(preset.id)
                        }
                    }
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .lineLimit(1)
            .layoutPriority(1)
            .accessibilityIdentifier("presetPicker")
            Spacer(minLength: 0)
            Button("変換") {
                session.convertTapped()
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("convertButton")
            Spacer(minLength: 0)
            Button {
                isShowingPresets = true
            } label: {
                Image(systemName: "gearshape")
            }
            .accessibilityLabel("プリセットの設定")
            .accessibilityIdentifier("settingsButton")
        }
    }

    private var presetSelection: Binding<UUID> {
        Binding(
            get: { session.selectedPresetID },
            set: { session.select($0) }
        )
    }
}

private extension View {
    func framed() -> some View {
        overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.separator)
        }
    }
}
