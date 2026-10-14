import SwiftUI

struct PlaygroundView: View {
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("Switch to the Bangla AI keyboard with 🌐 and try typing “ami bhat khai”.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                TextEditor(text: $text)
                    .focused($focused)
                    .font(.title3)
                    .padding(8)
                    .scrollContentBackground(.hidden)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
            }
            .padding()
            .navigationTitle("Try it")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("Copy") { UIPasteboard.general.string = text }
                        .disabled(text.isEmpty)
                    Button("Clear", role: .destructive) { text = "" }
                        .disabled(text.isEmpty)
                }
            }
            .onAppear { focused = true }
        }
    }
}
