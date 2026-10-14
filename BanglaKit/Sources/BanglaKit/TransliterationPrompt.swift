import Foundation

/// A single chat message sent to the OpenAI Chat Completions API.
public struct ChatMessage: Codable, Equatable, Sendable {
    public var role: String
    public var content: String

    public init(role: String, content: String) {
        self.role = role
        self.content = content
    }
}

/// Builds the prompt that turns Banglish (romanized Bengali) into Bengali script.
public enum TransliterationPrompt {
    public static let systemPrompt = """
    You convert romanized Bengali ("Banglish") into natural, correctly spelled Bengali script.
    Rules:
    - Fix spelling mistakes and use standard Bangla spelling.
    - Add proper punctuation, ending sentences with "।" (or "?" / "!" when appropriate).
    - Keep names, brands and technical terms in their usual form; use Bangla script for English words only when that is how Bangla speakers normally write them.
    - If the input is already in Bengali script, just correct it.
    - Output ONLY the converted text. No quotes, no explanations, no romanization.
    """

    /// Few-shot examples that keep the output format stable.
    public static let examples: [(input: String, output: String)] = [
        ("ami bhat khai", "আমি ভাত খাই।"),
        ("tumi kemon acho", "তুমি কেমন আছো?"),
        ("ajke onek brishti hocche, tai ami office e jabo na", "আজকে অনেক বৃষ্টি হচ্ছে, তাই আমি অফিসে যাবো না।"),
    ]

    public static func messages(for input: String) -> [ChatMessage] {
        var messages = [ChatMessage(role: "system", content: systemPrompt)]
        for example in examples {
            messages.append(ChatMessage(role: "user", content: example.input))
            messages.append(ChatMessage(role: "assistant", content: example.output))
        }
        messages.append(ChatMessage(role: "user", content: input.trimmingCharacters(in: .whitespacesAndNewlines)))
        return messages
    }

    /// Strips wrapping quotes / code fences / whitespace a model may add despite instructions.
    public static func cleanOutput(_ raw: String) -> String {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("```") {
            text = text
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let quotePairs: [(Character, Character)] = [("\"", "\""), ("“", "”"), ("'", "'"), ("‘", "’")]
        for (open, close) in quotePairs where text.count >= 2 && text.first == open && text.last == close {
            text = String(text.dropFirst().dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return text
    }
}
