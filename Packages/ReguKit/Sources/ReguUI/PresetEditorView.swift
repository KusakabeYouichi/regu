import ReguCore
import SwiftUI

// 1 プリセットの編集画面。numbers の group ごとに Section を分け、項目ごとに Picker を置く。
// 既定プリセットは読み取り専用
struct PresetEditorView: View {
    let store: PresetStore
    let presetID: UUID
    @State private var name = ""

    var body: some View {
        if let preset = store.preset(id: presetID) {
            form(for: preset)
        } else {
            ContentUnavailableView("プリセットが見つかりません", systemImage: "questionmark")
        }
    }

    private func form(for preset: Preset) -> some View {
        Form {
            Section("名前") {
                if preset.isBuiltIn {
                    Text(preset.name)
                    Text("既定のプリセットは変更できません。一覧で複製すると編集できます。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    TextField("名前", text: $name)
                        .accessibilityIdentifier("presetNameField")
                        .onAppear {
                            name = preset.name
                        }
                        .onChange(of: name) { _, newValue in
                            commitName(newValue)
                        }
                }
            }
            ForEach(SettingGroup.allCases) { group in
                Section(group.label) {
                    ForEach(group.fields) { field in
                        Picker(field.label, selection: selection(for: field)) {
                            ForEach(field.choices) { choice in
                                Text(choice.label).tag(choice.rawValue)
                            }
                        }
                        .accessibilityIdentifier("presetField.\(field.rawValue)")
                    }
                }
            }
            .disabled(preset.isBuiltIn)
        }
        .navigationTitle(preset.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    // 空の名前は保存しない（入力途中で消したときに一覧から名前が消えないように）。
    // 表示時に保存済みの名前を入れたときも onChange が来るので、変わっていなければ保存しない
    private func commitName(_ newValue: String) {
        guard !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              newValue != store.preset(id: presetID)?.name else {
            return
        }
        store.rename(presetID, to: newValue)
    }

    // 書き込みのたびに保存先の最新の値から作り直す（同じ描画内で複数項目を変えても上書きしない）
    private func selection(for field: SettingField) -> Binding<String> {
        Binding(
            get: { store.preset(id: presetID)?.settings.rawValue(for: field) ?? "" },
            set: { newValue in
                guard var settings = store.preset(id: presetID)?.settings else {
                    return
                }
                settings.setRawValue(newValue, for: field)
                store.updateSettings(presetID, to: settings)
            }
        )
    }
}
