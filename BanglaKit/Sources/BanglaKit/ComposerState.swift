import Foundation

public enum InputMode: String, CaseIterable, Sendable {
    /// Banglish typed into the compose bar, converted by AI.
    case ai
    /// Standard English keyboard typing directly into the app.
    case english
    /// Standard Bangla keyboard typing directly into the app.
    case bangla

    public var next: InputMode {
        switch self {
        case .ai: return .english
        case .english: return .bangla
        case .bangla: return .ai
        }
    }

    public var shortLabel: String {
        switch self {
        case .ai: return "AI"
        case .english: return "EN"
        case .bangla: return "বাং"
        }
    }
}

public enum ComposerPhase: Equatable, Sendable {
    case composing
    case converting
    case result
    case editing
    case error(String)
}

/// What the keyboard controller must do to the host text field after an action.
public enum ComposerEffect: Equatable, Sendable {
    case none
    case insert(String)
    case deleteBackward
    /// Delete `deleteCount` characters before the cursor, then insert `text`.
    case replaceBeforeCursor(deleteCount: Int, text: String)
    case convert(text: String, requestID: Int)
}

/// Pure state machine behind the keyboard. No UIKit, so it is unit tested.
public struct ComposerState: Equatable, Sendable {
    public private(set) var mode: InputMode
    /// Banglish typed by the user (AI mode).
    public private(set) var source: String = ""
    /// Bangla text returned by the AI, editable before inserting.
    public private(set) var result: String = ""
    /// Cursor inside `result`, counted in Unicode scalars so a vowel sign can be fixed on its own.
    public private(set) var resultCursor: Int = 0
    public private(set) var phase: ComposerPhase = .composing
    /// Layout used while editing the AI result.
    public var editLanguage: KeyboardLanguage = .bangla
    /// Characters in the host field that `source` was pulled from and should be replaced on insert.
    public private(set) var replaceCount: Int = 0
    public private(set) var requestID: Int = 0

    public init(mode: InputMode = .ai) {
        self.mode = mode
    }

    /// Which key layout the grid should show.
    public var displayLanguage: KeyboardLanguage {
        switch mode {
        case .english: return .english
        case .bangla: return .bangla
        case .ai: return phase == .editing ? editLanguage : .english
        }
    }

    public var isComposing: Bool { mode == .ai }
    public var hasSource: Bool { !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    /// Text before / after the cursor while editing the result.
    public var resultParts: (before: String, after: String) {
        let scalars = Array(result.unicodeScalars)
        let index = min(max(resultCursor, 0), scalars.count)
        var before = String.UnicodeScalarView(), after = String.UnicodeScalarView()
        before.append(contentsOf: scalars[..<index])
        after.append(contentsOf: scalars[index...])
        return (String(before), String(after))
    }

    // MARK: - Mode

    public mutating func setMode(_ newMode: InputMode) {
        if phase == .editing { phase = .result }
        mode = newMode
    }

    public mutating func cycleMode() {
        setMode(mode.next)
    }

    // MARK: - Typing

    public mutating func type(_ text: String) -> ComposerEffect {
        if mode == .ai && phase == .editing {
            var scalars = Array(result.unicodeScalars)
            let index = min(max(resultCursor, 0), scalars.count)
            let inserted = Array(text.unicodeScalars)
            scalars.insert(contentsOf: inserted, at: index)
            result = Self.string(from: scalars)
            resultCursor = index + inserted.count
            return .none
        }
        guard mode == .ai else { return .insert(text) }
        if phase == .converting { return .none }
        source += text
        invalidateResult()
        return .none
    }

    public mutating func backspace() -> ComposerEffect {
        guard mode == .ai else { return .deleteBackward }
        switch phase {
        case .editing:
            guard resultCursor > 0 else { return .none }
            var scalars = Array(result.unicodeScalars)
            scalars.remove(at: resultCursor - 1)
            result = Self.string(from: scalars)
            resultCursor -= 1
            return .none
        case .converting:
            return .none
        default:
            guard !source.isEmpty else { return .deleteBackward }
            source.removeLast()
            if source.isEmpty { replaceCount = 0 }
            invalidateResult()
            return .none
        }
    }

    /// Return key: newline when idle, convert when composing, insert when a result is shown,
    /// finish editing while editing.
    public mutating func returnKey() -> ComposerEffect {
        guard mode == .ai else { return .insert("\n") }
        switch phase {
        case .editing:
            phase = .result
            return .none
        case .result:
            return insert(trailingSpace: false)
        case .converting:
            return .none
        case .composing, .error:
            return hasSource ? convert() : .insert("\n")
        }
    }

    public var returnLabel: String {
        guard mode == .ai else { return "return" }
        switch phase {
        case .editing: return "Done"
        case .result: return "Insert"
        case .converting: return "…"
        case .composing, .error: return hasSource ? "Convert" : "return"
        }
    }

    // MARK: - AI flow

    public mutating func convert() -> ComposerEffect {
        guard mode == .ai, hasSource, phase != .converting else { return .none }
        requestID += 1
        phase = .converting
        return .convert(text: source, requestID: requestID)
    }

    /// Pulls existing Banglish from the host field (text on the current line before the cursor)
    /// into the compose bar so it can be converted and replaced in place.
    public mutating func useFieldText(_ contextBeforeCursor: String?) -> ComposerEffect {
        guard mode == .ai, phase != .converting else { return .none }
        let line = contextBeforeCursor?.components(separatedBy: "\n").last ?? ""
        guard !line.trimmingCharacters(in: .whitespaces).isEmpty else { return .none }
        source = line
        replaceCount = line.count
        invalidateResult()
        return convert()
    }

    public mutating func conversionSucceeded(_ text: String, requestID id: Int) {
        guard id == requestID, phase == .converting else { return }
        result = text
        resultCursor = text.unicodeScalars.count
        phase = .result
    }

    public mutating func conversionFailed(_ message: String, requestID id: Int) {
        guard id == requestID, phase == .converting else { return }
        phase = .error(message)
    }

    public mutating func startEditing() {
        guard phase == .result else { return }
        resultCursor = result.unicodeScalars.count
        phase = .editing
    }

    public mutating func finishEditing() {
        if phase == .editing { phase = .result }
    }

    public mutating func moveCursor(by offset: Int) {
        guard phase == .editing else { return }
        resultCursor = min(max(resultCursor + offset, 0), result.unicodeScalars.count)
    }

    public mutating func insert(trailingSpace: Bool) -> ComposerEffect {
        guard mode == .ai, phase == .result || phase == .editing, !result.isEmpty else { return .none }
        let text = trailingSpace ? result + " " : result
        let count = replaceCount
        clear()
        return count > 0 ? .replaceBeforeCursor(deleteCount: count, text: text) : .insert(text)
    }

    public mutating func clear() {
        source = ""
        result = ""
        resultCursor = 0
        replaceCount = 0
        phase = .composing
        requestID += 1 // drop any in-flight response
    }

    // MARK: - Helpers

    private mutating func invalidateResult() {
        if phase != .composing {
            result = ""
            resultCursor = 0
            phase = .composing
        }
    }

    private static func string(from scalars: [Unicode.Scalar]) -> String {
        var view = String.UnicodeScalarView()
        view.append(contentsOf: scalars)
        return String(view)
    }
}
