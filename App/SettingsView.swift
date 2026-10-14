import BanglaKit
import SwiftUI

struct SettingsView: View {
    private let keyStore = APIKeyStore()
    private let settings = SettingsStore()

    @State private var savedKey: String?
    @State private var keyInput = ""
    @State private var model = SettingsStore.defaultModel
    @State private var customModel = ""
    @State private var keyClicks = true
    @State private var haptics = true
    @State private var spaceAfterInsert = true
    @State private var livePreview = true

    @State private var testInput = "ami bhat khai"
    @State private var testOutput: String?
    @State private var testError: String?
    @State private var testing = false

    private static let customTag = "__custom__"

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if let savedKey {
                        LabeledContent("Saved key", value: APIKeyStore.masked(savedKey))
                    }
                    SecureField(savedKey == nil ? "sk-…" : "Replace key", text: $keyInput)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.body.monospaced())
                    HStack {
                        Button("Save key") { saveKey() }
                            .disabled(keyInput.trimmingCharacters(in: .whitespaces).isEmpty)
                        Spacer()
                        PasteButton(payloadType: String.self) { strings in
                            keyInput = strings.first ?? ""
                        }
                        .labelStyle(.titleOnly)
                    }
                    .buttonStyle(.borderless)
                    if savedKey != nil {
                        Button("Remove key", role: .destructive) {
                            keyStore.delete()
                            savedKey = nil
                        }
                    }
                } header: {
                    Text("OpenAI API key")
                } footer: {
                    Text("Create a key at platform.openai.com/api-keys. It's kept in the Keychain and only sent to api.openai.com.")
                }

                Section {
                    Picker("Model", selection: $model) {
                        ForEach(SettingsStore.suggestedModels, id: \.self) { Text($0).tag($0) }
                        Text("Custom…").tag(Self.customTag)
                    }
                    if model == Self.customTag {
                        TextField("Model name", text: $customModel)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .onSubmit { settings.model = customModel }
                    }
                } header: {
                    Text("Model")
                } footer: {
                    Text("gpt-4o-mini is fast and inexpensive. Larger models may spell rare words better.")
                }

                Section("Test") {
                    TextField("Banglish", text: $testInput)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button {
                        Task { await runTest() }
                    } label: {
                        HStack {
                            Text("Convert")
                            if testing { Spacer(); ProgressView() }
                        }
                    }
                    .disabled(testing || savedKey == nil || testInput.isEmpty)
                    if let testOutput {
                        Text(testOutput).font(.title3).textSelection(.enabled)
                    }
                    if let testError {
                        Text(testError).font(.footnote).foregroundStyle(.red)
                    }
                }

                Section {
                    Toggle("Live preview while typing", isOn: $livePreview)
                    Toggle("Key click sounds", isOn: $keyClicks)
                    Toggle("Haptic feedback", isOn: $haptics)
                    Toggle("Add space after inserting", isOn: $spaceAfterInsert)
                } header: {
                    Text("Keyboard")
                } footer: {
                    Text("Live preview converts in the background each time you pause, so Insert is instant. It sends a request per pause, which uses a little more of your OpenAI quota.")
                }
            }
            .navigationTitle("Settings")
            .onAppear(perform: load)
            .onChange(of: model) { _, value in
                settings.model = value == Self.customTag ? customModel : value
            }
            .onChange(of: customModel) { _, value in
                if model == Self.customTag { settings.model = value }
            }
            .onChange(of: keyClicks) { _, value in settings.keyClicks = value }
            .onChange(of: haptics) { _, value in settings.haptics = value }
            .onChange(of: spaceAfterInsert) { _, value in settings.spaceAfterInsert = value }
            .onChange(of: livePreview) { _, value in settings.livePreview = value }
        }
    }

    private func load() {
        savedKey = keyStore.load()
        let stored = settings.model
        if SettingsStore.suggestedModels.contains(stored) {
            model = stored
        } else {
            customModel = stored
            model = Self.customTag
        }
        keyClicks = settings.keyClicks
        haptics = settings.haptics
        spaceAfterInsert = settings.spaceAfterInsert
        livePreview = settings.livePreview
    }

    private func saveKey() {
        let key = keyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if keyStore.save(key) {
            savedKey = keyStore.load()
            keyInput = ""
            testOutput = nil
            testError = nil
        } else {
            testError = "Couldn't save the key to the Keychain."
        }
    }

    private func runTest() async {
        guard let key = keyStore.load() else { return }
        testing = true
        testOutput = nil
        testError = nil
        defer { testing = false }
        do {
            testOutput = try await OpenAIClient(apiKey: key, model: settings.model).transliterate(testInput)
        } catch {
            testError = error.localizedDescription
        }
    }
}
