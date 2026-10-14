import Foundation

public enum KeyboardLanguage: String, Sendable {
    case english
    case bangla
}

public enum KeyboardLayer: String, Sendable {
    case letters
    case numbers
    case symbols
}

public enum KeyAction: Hashable, Sendable {
    case character(String)
    case shift
    case backspace
    case layer(KeyboardLayer)
}

public struct KeySpec: Hashable, Identifiable, Sendable {
    public var id: String { "\(label)|\(action)" }
    public var label: String
    public var action: KeyAction
    /// Width relative to a standard letter key.
    public var width: Double

    public init(_ label: String, _ action: KeyAction, width: Double = 1) {
        self.label = label
        self.action = action
        self.width = width
    }

    public static func char(_ value: String) -> KeySpec { KeySpec(value, .character(value)) }
    public var isSpecial: Bool {
        if case .character = action { return false }
        return true
    }
}

/// Key rows (excluding the bottom row with space/return, which the UI builds).
public enum KeyboardLayouts {
    // MARK: English
    static let englishRows = ["qwertyuiop", "asdfghjkl", "zxcvbnm"]
    static let englishNumbers = [
        ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"],
        ["-", "/", ":", ";", "(", ")", "$", "&", "@", "\""],
        [".", ",", "?", "!", "'"],
    ]
    static let englishSymbols = [
        ["[", "]", "{", "}", "#", "%", "^", "*", "+", "="],
        ["_", "\\", "|", "~", "<", ">", "€", "£", "¥", "•"],
        [".", ",", "?", "!", "'"],
    ]

    // MARK: Bangla (phonetic-style: keys sit roughly where their sound is on QWERTY,
    // shift gives the aspirated / alternate form of the same key)
    // য় ড় ঢ় are written as base + nukta (U+09BC), the normalized form.
    static let banglaNormal = [
        ["ঙ", "ৌ", "ে", "র", "ত", "য\u{09BC}", "ু", "ি", "ো", "প"],
        ["া", "স", "দ", "ৃ", "গ", "হ", "জ", "ক", "ল"],
        ["য", "শ", "চ", "ভ", "ব", "ন", "ম", "্"],
    ]
    static let banglaShifted = [
        ["ঞ", "ৈ", "এ", "ড\u{09BC}", "ট", "ঢ\u{09BC}", "ূ", "ী", "ও", "ফ"],
        ["আ", "ষ", "ড", "ঋ", "ঘ", "ঃ", "ঝ", "খ", "ং"],
        ["ঠ", "থ", "ছ", "ঢ", "ধ", "ণ", "ৎ", "ঁ"],
    ]
    static let banglaNumbers = [
        ["১", "২", "৩", "৪", "৫", "৬", "৭", "৮", "৯", "০"],
        ["অ", "ই", "ঈ", "উ", "ঊ", "ঐ", "ঔ", "ৗ", "৳"],
        ["।", ",", "?", "!", "-"],
    ]

    public static func rows(language: KeyboardLanguage, layer: KeyboardLayer, shifted: Bool) -> [[KeySpec]] {
        switch (language, layer) {
        case (.english, .letters):
            var rows = englishRows.map { row in
                row.map { KeySpec.char(shifted ? $0.uppercased() : String($0)) }
            }
            rows[2] = [KeySpec("⇧", .shift, width: 1.4)] + rows[2] + [KeySpec("⌫", .backspace, width: 1.4)]
            return rows
        case (.english, .numbers):
            return symbolRows(englishNumbers, toggle: KeySpec("#+=", .layer(.symbols), width: 1.4))
        case (_, .symbols):
            return symbolRows(englishSymbols, toggle: KeySpec("123", .layer(.numbers), width: 1.4))
        case (.bangla, .letters):
            var rows = (shifted ? banglaShifted : banglaNormal).map { $0.map(KeySpec.char) }
            rows[2] = [KeySpec("⇧", .shift, width: 1.2)] + rows[2] + [KeySpec("⌫", .backspace, width: 1.2)]
            return rows
        case (.bangla, .numbers):
            return symbolRows(banglaNumbers, toggle: KeySpec("#+=", .layer(.symbols), width: 1.4))
        }
    }

    private static func symbolRows(_ source: [[String]], toggle: KeySpec) -> [[KeySpec]] {
        var rows = source.map { $0.map(KeySpec.char) }
        rows[2] = [toggle] + rows[2].map { var key = $0; key.width = 1.4; return key } + [KeySpec("⌫", .backspace, width: 1.4)]
        return rows
    }

    /// Label for the key that switches from letters to the numbers layer.
    public static func numbersLabel(for language: KeyboardLanguage) -> String {
        language == .bangla ? "১২৩" : "123"
    }

    public static func lettersLabel(for language: KeyboardLanguage) -> String {
        language == .bangla ? "কখগ" : "ABC"
    }
}
