import SwiftUI

struct RenameSheet: View {
    let title: String
    @Binding var isPresented: Bool
    let initial: String
    var characterLimit: Int = 60
    let onSave: (String) -> Void

    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $text)
                    .focused($focused)
                    .autocorrectionDisabled()
                    .onChange(of: text) { _, new in
                        if new.count > characterLimit {
                            text = String(new.prefix(characterLimit))
                        }
                    }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmed = text.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        onSave(String(trimmed.prefix(characterLimit)))
                        isPresented = false
                        Haptics.success()
                    }
                    .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.height(180)])
        .presentationDragIndicator(.visible)
        .onAppear {
            text = String(initial.prefix(characterLimit))
            focused = true
        }
    }
}
