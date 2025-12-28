import SwiftUI

enum FolderEditMode {
    case create
    case edit(String)

    var title: String {
        switch self {
        case .create: return "New Folder"
        case .edit: return "Rename Folder"
        }
    }

    var buttonLabel: String {
        switch self {
        case .create: return "Create"
        case .edit: return "Save"
        }
    }

    var initialName: String {
        switch self {
        case .create: return ""
        case .edit(let name): return name
        }
    }
}

struct FolderEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    let mode: FolderEditMode
    let onSave: (String) -> Void

    @State private var name: String
    @FocusState private var isNameFocused: Bool

    init(mode: FolderEditMode, onSave: @escaping (String) -> Void) {
        self.mode = mode
        self.onSave = onSave
        self._name = State(initialValue: mode.initialName)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Folder name", text: $name)
                        .focused($isNameFocused)
                } footer: {
                    Text("Give your folder a name that makes sense to YOU. We won't rename it to \"Recents\" or \"Favorites\" without asking.")
                }
            }
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(mode.buttonLabel) {
                        onSave(name.trimmingCharacters(in: .whitespacesAndNewlines))
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                isNameFocused = true
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview("Create") {
    FolderEditSheet(mode: .create) { name in
        print("Created: \(name)")
    }
}

#Preview("Edit") {
    FolderEditSheet(mode: .edit("Vacation 2024")) { name in
        print("Renamed to: \(name)")
    }
}
