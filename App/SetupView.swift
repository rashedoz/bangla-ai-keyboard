import BanglaKit
import SwiftUI

struct SetupView: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var hasKey = APIKeyStore().load() != nil

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Write Bangla by typing Banglish")
                            .font(.headline)
                        Text("Type “ami bhat khai”, tap Convert, and get “আমি ভাত খাই।” — right inside any app.")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                Section("Steps") {
                    step(1, "Add your OpenAI API key", done: hasKey,
                         detail: "Settings tab → paste your key. It is stored in the Keychain on this device only.")
                    step(2, "Add the keyboard", done: false,
                         detail: "Settings › General › Keyboard › Keyboards › Add New Keyboard… › Bangla AI")
                    step(3, "Allow Full Access", done: false,
                         detail: "Tap Bangla AI in that list and turn on Allow Full Access. It's needed so the keyboard can reach OpenAI.")
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                }

                Section("Using the keyboard") {
                    tip("globe", "Hold the 🌐 key and pick Bangla AI.")
                    tip("sparkles", "AI mode: type Banglish into the bar, tap Convert, then Insert.")
                    tip("pencil", "Edit fixes words in the result with the Bangla keys before inserting.")
                    tip("text.insert", "↥ converts the Banglish already written before the cursor and replaces it.")
                    tip("arrow.left.arrow.right", "The AI / EN / বাং key switches to the plain English or Bangla keyboard.")
                }

                Section("Privacy") {
                    Text("Only the text you choose to convert is sent to OpenAI with your own API key. Nothing else you type leaves the keyboard.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Bangla AI Keyboard")
            .onChange(of: scenePhase) { _, _ in hasKey = APIKeyStore().load() != nil }
            .onAppear { hasKey = APIKeyStore().load() != nil }
        }
    }

    private func step(_ number: Int, _ title: String, done: Bool, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: done ? "checkmark.circle.fill" : "\(number).circle")
                .font(.title2)
                .foregroundStyle(done ? .green : .accentColor)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.body.weight(.semibold))
                Text(detail).font(.footnote).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private func tip(_ icon: String, _ text: String) -> some View {
        Label(text, systemImage: icon).font(.subheadline)
    }
}
