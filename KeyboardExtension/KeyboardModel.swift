import BanglaKit
import SwiftUI
import UIKit

enum ShiftState {
    case off, once, locked
}

@MainActor
final class KeyboardModel: ObservableObject {
    @Published private(set) var state: ComposerState
    @Published private(set) var shift: ShiftState = .off
    @Published private(set) var layer: KeyboardLayer = .letters
    @Published var needsGlobeKey = true
    @Published private(set) var hasFullAccess = false

    weak var controller: UIInputViewController?
    private let settings = SettingsStore()
    private var conversionTask: Task<Void, Never>?
    private var lastShiftTap = Date.distantPast
    private lazy var haptic = UIImpactFeedbackGenerator(style: .light)

    init(controller: UIInputViewController) {
        self.controller = controller
        self.state = ComposerState(mode: SettingsStore().lastMode)
    }

    private var proxy: UITextDocumentProxy? { controller?.textDocumentProxy }

    func refreshEnvironment() {
        hasFullAccess = controller?.hasFullAccess ?? false
        needsGlobeKey = controller?.needsInputModeSwitchKey ?? true
    }

    // MARK: - Derived

    var rows: [[KeySpec]] {
        KeyboardLayouts.rows(language: state.displayLanguage, layer: layer, shifted: shift != .off)
    }

    var layerKeyLabel: String {
        layer == .letters
            ? KeyboardLayouts.numbersLabel(for: state.displayLanguage)
            : KeyboardLayouts.lettersLabel(for: state.displayLanguage)
    }

    var modeKeyLabel: String {
        if state.phase == .editing {
            return state.editLanguage == .bangla ? "EN" : "বাং"
        }
        return state.mode.next.shortLabel
    }

    var returnLabel: String { state.returnLabel }

    var returnIsProminent: Bool {
        state.mode == .ai && ["Convert", "Insert", "Done"].contains(state.returnLabel)
    }

    // MARK: - Keys

    func tap(_ key: KeySpec) {
        feedback()
        switch key.action {
        case .character(let value):
            apply(state.type(value))
            if shift == .once { shift = .off }
        case .shift:
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
            layer = newLayer
        }
    }

    func backspace() {
        feedback()
        apply(state.backspace())
    }

    func space() {
        feedback()
        apply(state.type(" "))
        if layer != .letters { layer = .letters }
    }

    func returnKey() {
        feedback()
        if state.mode == .ai && state.phase == .result {
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
        shift = .off
        layer = .letters
    }

    func switchToAI() {
        state.setMode(.ai)
        settings.lastMode = .ai
        layer = .letters
    }

    // MARK: - Compose bar

    func convert() { apply(state.convert()) }

    func insertResult() {
        apply(state.insert(trailingSpace: settings.spaceAfterInsert))
    }

    func edit() {
        state.startEditing()
        layer = .letters
        shift = .off
    }

    func finishEditing() { state.finishEditing() }

    func moveCursor(_ offset: Int) {
        feedback()
        state.moveCursor(by: offset)
    }

    func clear() {
        conversionTask?.cancel()
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
        }
    }

    private func startConversion(_ text: String, requestID: Int) {
        refreshEnvironment()
        guard hasFullAccess else {
            state.conversionFailed(TransliterationError.noFullAccess.localizedDescription, requestID: requestID)
            return
        }
        guard let key = APIKeyStore().load() else {
            state.conversionFailed(TransliterationError.missingAPIKey.localizedDescription, requestID: requestID)
            return
        }
        let client = OpenAIClient(apiKey: key, model: settings.model)
        conversionTask?.cancel()
        conversionTask = Task { [weak self] in
            do {
                let output = try await client.transliterate(text)
                guard !Task.isCancelled else { return }
                self?.state.conversionSucceeded(output, requestID: requestID)
            } catch {
                guard !Task.isCancelled else { return }
                self?.state.conversionFailed(error.localizedDescription, requestID: requestID)
            }
        }
    }

    private func feedback() {
        if settings.keyClicks { UIDevice.current.playInputClick() }
        if settings.haptics && hasFullAccess { haptic.impactOccurred(intensity: 0.6) }
    }
}
