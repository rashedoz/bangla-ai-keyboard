import BanglaKit
import SwiftUI
import UIKit

enum ShiftState {
    case off, once, locked
}

/// Everything the key grid needs to draw itself. The grid only re-renders when this changes,
/// so typing into the compose bar doesn't redraw every key.
struct GridConfig: Equatable {
    var rows: [[KeySpec]]
    var language: KeyboardLanguage
    var shift: ShiftState
    var layerLabel: String
    var modeLabel: String
    var returnLabel: String
    var returnProminent: Bool
    var needsGlobe: Bool
    var spaceLabel: String
}

@MainActor
final class KeyboardModel: ObservableObject {
    @Published private(set) var state: ComposerState
    @Published private(set) var shift: ShiftState = .off
    @Published private(set) var layer: KeyboardLayer = .letters
    @Published private(set) var needsGlobeKey = true
    @Published private(set) var hasFullAccess = false

    weak var controller: UIInputViewController?
    private let settings = SettingsStore()
    private var conversionTask: Task<Void, Never>?
    private var previewTask: Task<Void, Never>?
    private var lastShiftTap = Date.distantPast
    private let haptic = UIImpactFeedbackGenerator(style: .light)

    // Settings are read once per appearance, not on every key press.
    private var keyClicks = true
    private var haptics = true
    private var livePreview = true
    private var spaceAfterInsert = true
    private var model = SettingsStore.defaultModel
    private var apiKey: String?

    /// Pause after the last keystroke before a live preview request is sent.
    private let previewDelay: Duration = .milliseconds(350)

    init(controller: UIInputViewController) {
        self.controller = controller
        self.state = ComposerState(mode: SettingsStore().lastMode)
    }

    private var proxy: UITextDocumentProxy? { controller?.textDocumentProxy }

    /// Called when the keyboard appears: reload settings and open the network connection early.
    func keyboardWillAppear() {
        updateEnvironment()
        keyClicks = settings.keyClicks
        haptics = settings.haptics
        livePreview = settings.livePreview
        spaceAfterInsert = settings.spaceAfterInsert
        model = settings.model
        apiKey = hasFullAccess ? APIKeyStore().load() : nil
        if haptics && hasFullAccess { haptic.prepare() }
        if hasFullAccess && apiKey != nil && state.mode == .ai { OpenAIClient.prewarm() }
    }

    /// Cheap check that only publishes when something actually changed.
    func updateEnvironment() {
        let access = controller?.hasFullAccess ?? false
        let globe = controller?.needsInputModeSwitchKey ?? true
        if access != hasFullAccess { hasFullAccess = access }
        if globe != needsGlobeKey { needsGlobeKey = globe }
    }

    // MARK: - Derived

    var gridConfig: GridConfig {
        let language = state.displayLanguage
        return GridConfig(
            rows: KeyboardLayouts.rows(language: language, layer: layer, shifted: shift != .off),
            language: language,
            shift: shift,
            layerLabel: layer == .letters
                ? KeyboardLayouts.numbersLabel(for: language)
                : KeyboardLayouts.lettersLabel(for: language),
            modeLabel: state.phase == .editing
                ? (state.editLanguage == .bangla ? "EN" : "বাং")
                : state.mode.next.shortLabel,
            returnLabel: state.returnLabel,
            returnProminent: state.mode == .ai && ["Convert", "Insert", "Done"].contains(state.returnLabel),
            needsGlobe: needsGlobeKey,
            spaceLabel: spaceLabel
        )
    }

    private var spaceLabel: String {
        switch state.mode {
        case .ai: return state.phase == .editing ? "বাংলা (edit)" : "Banglish → বাংলা"
        case .english: return "English"
        case .bangla: return "বাংলা"
        }
    }

    // MARK: - Keys

    func tap(_ key: KeySpec) {
        switch key.action {
        case .character(let value):
            feedback()
            apply(state.type(value))
            if shift == .once { shift = .off }
            schedulePreview()
        case .shift:
            feedback()
            let now = Date()
            if shift == .locked {
                shift = .off
            } else if now.timeIntervalSince(lastShiftTap) < 0.35 {
                shift = .locked
            } else {
                shift = shift == .off ? .once : .off
            }
            lastShiftTap = now
        case .backspace:
            backspace()
        case .layer(let newLayer):
            feedback()
            layer = newLayer
        }
    }

    func backspace() {
        feedback()
        apply(state.backspace())
        schedulePreview()
    }

    func space() {
        feedback()
        apply(state.type(" "))
        if layer != .letters { layer = .letters }
        schedulePreview()
    }

    func returnKey() {
        feedback()
        if state.mode == .ai && (state.phase == .result || state.isPreviewFresh) {
            insertResult()
        } else {
            apply(state.returnKey())
        }
    }

    func toggleLayer() {
        feedback()
        layer = layer == .letters ? .numbers : .letters
    }

    /// The AI / EN / বাং key. While editing an AI result it flips the edit layout instead.
    func modeKey() {
        feedback()
        if state.phase == .editing {
            state.editLanguage = state.editLanguage == .bangla ? .english : .bangla
        } else {
            state.cycleMode()
            settings.lastMode = state.mode
        }
        if shift != .off { shift = .off }
        if layer != .letters { layer = .letters }
    }

    func switchToAI() {
        state.setMode(.ai)
        settings.lastMode = .ai
        if layer != .letters { layer = .letters }
    }

    // MARK: - Compose bar

    func convert() {
        previewTask?.cancel()
        apply(state.convert())
    }

    func insertResult() {
        previewTask?.cancel()
        apply(state.insert(trailingSpace: spaceAfterInsert))
    }

    func edit() {
        previewTask?.cancel()
        state.editPreview()
        if layer != .letters { layer = .letters }
        if shift != .off { shift = .off }
    }

    func finishEditing() { state.finishEditing() }

    func moveCursor(_ offset: Int) {
        feedback()
        state.moveCursor(by: offset)
    }

    func clear() {
        conversionTask?.cancel()
        previewTask?.cancel()
        state.clear()
    }

    func useFieldText() {
        apply(state.useFieldText(proxy?.documentContextBeforeInput))
    }

    // MARK: - Effects

    private func apply(_ effect: ComposerEffect) {
        switch effect {
        case .none:
            break
        case .insert(let text):
            proxy?.insertText(text)
        case .deleteBackward:
            proxy?.deleteBackward()
        case .replaceBeforeCursor(let count, let text):
            for _ in 0..<count { proxy?.deleteBackward() }
            proxy?.insertText(text)
        case .convert(let text, let requestID):
            startConversion(text, requestID: requestID)
        case .preview(let text, let requestID):
            startPreview(text, requestID: requestID)
        }
    }

    /// Debounces live previews: each keystroke restarts the timer.
    private func schedulePreview() {
        guard livePreview, state.mode == .ai, state.phase == .composing else { return }
        previewTask?.cancel()
        guard state.hasSource, !state.isPreviewFresh else { return }
        previewTask = Task { [weak self, previewDelay] in
            try? await Task.sleep(for: previewDelay)
            guard !Task.isCancelled, let self else { return }
            self.apply(self.state.requestPreview())
        }
    }

    private func client() -> OpenAIClient? {
        guard hasFullAccess else { return nil }
        if apiKey == nil { apiKey = APIKeyStore().load() }
        guard let apiKey else { return nil }
        return OpenAIClient(apiKey: apiKey, model: model)
    }

    private func startPreview(_ text: String, requestID: Int) {
        guard let client = client() else {
            state.previewFailed(requestID: requestID)
            return
        }
        previewTask = Task { [weak self] in
            do {
                var last = ""
                for try await partial in client.streamTransliteration(text) {
                    guard !Task.isCancelled else { return }
                    last = partial
                    self?.state.previewProgress(partial, requestID: requestID)
                }
                self?.state.previewSucceeded(last, requestID: requestID)
            } catch {
                self?.state.previewFailed(requestID: requestID)
            }
        }
    }

    private func startConversion(_ text: String, requestID: Int) {
        updateEnvironment()
        guard hasFullAccess else {
            state.conversionFailed(TransliterationError.noFullAccess.localizedDescription, requestID: requestID)
            return
        }
        guard let client = client() else {
            state.conversionFailed(TransliterationError.missingAPIKey.localizedDescription, requestID: requestID)
            return
        }
        conversionTask?.cancel()
        conversionTask = Task { [weak self] in
            do {
                var last = ""
                for try await partial in client.streamTransliteration(text) {
                    guard !Task.isCancelled else { return }
                    last = partial
                    self?.state.conversionProgress(partial, requestID: requestID)
                }
                self?.state.conversionSucceeded(last, requestID: requestID)
            } catch {
                guard !Task.isCancelled, !(error is CancellationError) else { return }
                self?.state.conversionFailed(error.localizedDescription, requestID: requestID)
            }
        }
    }

    private func feedback() {
        if keyClicks { UIDevice.current.playInputClick() }
        if haptics && hasFullAccess {
            haptic.impactOccurred(intensity: 0.6)
            haptic.prepare()
        }
    }
}
