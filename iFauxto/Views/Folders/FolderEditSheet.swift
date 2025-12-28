import SwiftUI

enum FolderEditMode {
    case create
    case edit(String)

    var title: String {
        switch self {
        case .create: return "New Folder"
        case .edit: return "Rename"
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
        VStack(spacing: 20) {
            Text(mode.title)
                .font(.title3.weight(.semibold))

            TextField("Folder name", text: $name)
                .padding(14)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .focused($isNameFocused)
                .onSubmit {
                    save()
                }

            HStack(spacing: 12) {
                Button {
                    dismiss()
                } label: {
                    Text("Cancel")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .foregroundStyle(.primary)
                .background(Color(.systemGray5))
                .clipShape(RoundedRectangle(cornerRadius: 14))

                Button {
                    save()
                } label: {
                    Text(mode.buttonLabel)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .foregroundStyle(.white)
                .background(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.accentColor)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .shadow(color: .black.opacity(0.2), radius: 30, y: 10)
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.4).ignoresSafeArea())
        .onAppear {
            isNameFocused = true
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onSave(trimmed)
        dismiss()
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
