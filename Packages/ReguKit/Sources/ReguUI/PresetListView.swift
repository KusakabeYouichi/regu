import ReguCore
import SwiftUI

// プリセットの一覧(sheet)。ビルトインは閲覧・別名の変更・複製だけ、ユーザープリセットは追加・複製・削除できる
struct PresetListView: View {
    let store: PresetStore
    @Environment(\.dismiss) private var dismiss
    @State private var path: [UUID] = []

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section("ビルトイン") {
                    ForEach(Preset.builtIns) { preset in
                        row(for: preset)
                    }
                }
                Section("ユーザー設定") {
                    ForEach(store.userPresets) { preset in
                        row(for: preset)
                    }
                    .onDelete { offsets in
                        let ids = offsets.map { store.userPresets[$0].id }
                        ids.forEach(store.delete)
                    }
                }
            }
            .navigationTitle("プリセット")
            .navigationDestination(for: UUID.self) { id in
                PresetEditorView(store: store, presetID: id)
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") {
                        dismiss()
                    }
                    .accessibilityIdentifier("closePresetsButton")
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        let preset = store.add(name: "新しいプリセット")
                        path.append(preset.id)
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("プリセットを追加")
                    .accessibilityIdentifier("addPresetButton")
                }
            }
        }
        .tint(Theme.accent)
    }

    private func row(for preset: Preset) -> some View {
        NavigationLink(value: preset.id) {
            Text(store.listName(for: preset))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .truncationMode(.tail)
        }
        .accessibilityIdentifier("presetRow.\(preset.id.uuidString)")
        .swipeActions(edge: .leading) {
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
        guard let copy = store.duplicate(preset.id, name: "\(preset.name) のコピー") else {
            return
        }
        path.append(copy.id)
    }
}
