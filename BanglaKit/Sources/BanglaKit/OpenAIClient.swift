import Foundation

public enum TransliterationError: Error, Equatable, LocalizedError {
    case missingAPIKey
    case noFullAccess
    case invalidAPIKey
    case rateLimited
    case server(Int)
    case http(Int, String)
    case network(String)
    case emptyResponse

    public var errorDescription: String? {
        switch self {
        case .missingAPIKey: return "Add your OpenAI API key in the Bangla AI app."
        case .noFullAccess: return "Turn on Allow Full Access: Settings › General › Keyboard › Keyboards › Bangla AI."
        case .invalidAPIKey: return "API key rejected (401). Check the key in the Bangla AI app."
        case .rateLimited: return "Rate limit or quota reached (429). Try again later or check your OpenAI billing."
        case .server(let code): return "OpenAI server error (\(code)). Try again."
        case .http(let code, let message): return message.isEmpty ? "Request failed (\(code))." : message
        case .network(let message): return "Network error: \(message)"
        case .emptyResponse: return "OpenAI returned an empty response."
        }
    }
}

public protocol Transliterating: Sendable {
    func transliterate(_ text: String) async throws -> String
}

/// Minimal OpenAI Chat Completions client for Banglish → Bangla conversion.
public struct OpenAIClient: Transliterating {
    public static let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!

    public var apiKey: String
    public var model: String
    public var session: URLSession

    public init(apiKey: String, model: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.model = model
        self.session = session
    }

    public func transliterate(_ text: String) async throws -> String {
        let request = try Self.makeRequest(input: text, apiKey: apiKey, model: model)
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw TransliterationError.network(error.localizedDescription)
        }
        return try Self.parse(data: data, response: response)
    }

    // MARK: - Request / response (pure, unit tested)

    struct RequestBody: Encodable {
        let model: String
        let messages: [ChatMessage]
        let temperature: Double
    }

    public static func makeRequest(input: String, apiKey: String, model: String) throws -> URLRequest {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw TransliterationError.missingAPIKey }
        var request = URLRequest(url: endpoint, timeoutInterval: 20)
        request.httpMethod = "POST"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = RequestBody(model: model, messages: TransliterationPrompt.messages(for: input), temperature: 0.2)
        request.httpBody = try JSONEncoder().encode(body)
        return request
    }

    struct ResponseBody: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable { let content: String? }
            let message: Message
        }
        let choices: [Choice]
    }

    struct ErrorBody: Decodable {
        struct Detail: Decodable { let message: String? }
        let error: Detail
    }

    public static func parse(data: Data, response: URLResponse) throws -> String {
        let status = (response as? HTTPURLResponse)?.statusCode ?? 200
        switch status {
        case 200..<300:
            break
        case 401:
            throw TransliterationError.invalidAPIKey
        case 429:
            throw TransliterationError.rateLimited
        case 500...:
            throw TransliterationError.server(status)
        default:
            let message = (try? JSONDecoder().decode(ErrorBody.self, from: data))?.error.message ?? ""
            throw TransliterationError.http(status, message)
        }
        guard let body = try? JSONDecoder().decode(ResponseBody.self, from: data),
              let content = body.choices.first?.message.content else {
            throw TransliterationError.emptyResponse
        }
        let cleaned = TransliterationPrompt.cleanOutput(content)
        guard !cleaned.isEmpty else { throw TransliterationError.emptyResponse }
        return cleaned
    }
}
