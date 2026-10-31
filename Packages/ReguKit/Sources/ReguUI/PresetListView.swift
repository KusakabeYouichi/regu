import ReguCore
import SwiftUI

// プリセットの一覧(sheet)。ビルトインは閲覧・別名の変更・複製だけ、ユーザープリセットは追加・複製・削除できる
struct PresetListView: View {
    private static let newPresetName = "新しいプリセット"

    let store: PresetStore
    @Environment(\.dismiss) private var dismiss
    @State private var path: [UUID] = []
    // + で追加して編集中のプリセットと、付けた名前。何も変えずに編集画面から離れたら追加しなかったことにする
    @State private var newPresetID: UUID?
    @State private var newPresetAssignedName = PresetListView.newPresetName

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section("ビルトイン") {
                    ForEach(Preset.builtIns) { preset in
                        row(for: preset)
                    }
                }
                Section {
                    ForEach(store.userPresets) { preset in
                        row(for: preset)
                    }
                } header: {
                    userPresetsHeader
                }
            }
            .navigationTitle("プリセット")
            .navigationDestination(for: UUID.self) { id in
                // 戻る途中(退場のアニメーション中)に消すと編集画面が「見つかりません」に変わって見えるので、消えきってから判定する。
                // 一覧ごと閉じたときもここに来る
                PresetEditorView(store: store, presetID: id)
                    .onDisappear {
                        if id == newPresetID {
                            discardNewPresetIfUntouched()
                        }
                    }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") {
                        dismiss()
                    }
                    .accessibilityIdentifier("closePresetsButton")
                }
            }
        }
        .tint(Theme.accent)
    }

    // 追加は「ユーザー設定」に対する操作なので、その見出しの右端に置く
    private var userPresetsHeader: some View {
        HStack {
            Text("ユーザー設定")
            Spacer()
            Button {
                // 既定の名前が埋まっていれば「新しいプリセット 2」…にする
                let preset = store.add(name: store.unusedName(startingWith: Self.newPresetName))
                newPresetID = preset.id
                newPresetAssignedName = preset.name
                path.append(preset.id)
            } label: {
                Image(systemName: "plus")
                    .font(.body.weight(.semibold))
                    .frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel("プリセットを追加")
            .accessibilityIdentifier("addPresetButton")
        }
    }

    private func discardNewPresetIfUntouched() {
        guard let id = newPresetID else {
            return
        }
        newPresetID = nil
        store.discardIfUntouched(id, defaultName: newPresetAssignedName)
    }

    private func row(for preset: Preset) -> some View {
        NavigationLink(value: preset.id) {
            Text(store.listName(for: preset))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .truncationMode(.tail)
        }
        .accessibilityIdentifier("presetRow.\(preset.id.uuidString)")
        // 行の操作は iOS の定番どおり左へのスワイプにまとめる(ユーザープリセットは削除も)。
        // 払い切っただけで複製・削除しないよう、ボタンを押したときだけ実行する
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if !preset.isBuiltIn {
                Button("削除", role: .destructive) {
                    store.delete(preset.id)
                }
            }
            Button("複製") {
                duplicate(preset)
            }
        }
        .contextMenu {
            Button("複製") {
                duplicate(preset)
            }
            if !preset.isBuiltIn {
                Button("削除", role: .destructive) {
                    store.delete(preset.id)
                }
            }
        }
    }

    private func duplicate(_ preset: Preset) {
        guard let copy = store.duplicate(preset.id) else {
            return
        }
        path.append(copy.id)
    }
}
