import XCTest
@testable import BanglaKit

final class TransliterationPromptTests: XCTestCase {
    func testMessagesIncludeSystemExamplesAndTrimmedInput() {
        let messages = TransliterationPrompt.messages(for: "  ami bhat khai \n")
        XCTAssertEqual(messages.first?.role, "system")
        XCTAssertEqual(messages.last, ChatMessage(role: "user", content: "ami bhat khai"))
        XCTAssertEqual(messages.count, 2 + TransliterationPrompt.examples.count * 2)
    }

    func testCleanOutputStripsQuotesAndFences() {
        XCTAssertEqual(TransliterationPrompt.cleanOutput("\"আমি ভাত খাই।\""), "আমি ভাত খাই।")
        XCTAssertEqual(TransliterationPrompt.cleanOutput("“আমি ভাত খাই।”\n"), "আমি ভাত খাই।")
        XCTAssertEqual(TransliterationPrompt.cleanOutput("```\nআমি ভাত খাই।\n```"), "আমি ভাত খাই।")
        XCTAssertEqual(TransliterationPrompt.cleanOutput("আমি ভাত খাই।"), "আমি ভাত খাই।")
    }
}

final class OpenAIClientTests: XCTestCase {
    private func response(_ status: Int) -> HTTPURLResponse {
        HTTPURLResponse(url: OpenAIClient.endpoint, statusCode: status, httpVersion: nil, headerFields: nil)!
    }

    func testMakeRequestBuildsAuthorizedJSONPost() throws {
        let request = try OpenAIClient.makeRequest(input: "ami bhat khai", apiKey: " sk-test ", model: "gpt-4o-mini")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url, OpenAIClient.endpoint)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer sk-test")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")

        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as? [String: Any])
        XCTAssertEqual(json["model"] as? String, "gpt-4o-mini")
        XCTAssertEqual(json["temperature"] as? Double, 0.2)
        let messages = try XCTUnwrap(json["messages"] as? [[String: String]])
        XCTAssertEqual(messages.last?["content"], "ami bhat khai")
    }

    func testMakeRequestRequiresKey() {
        XCTAssertThrowsError(try OpenAIClient.makeRequest(input: "x", apiKey: "  ", model: "m")) {
            XCTAssertEqual($0 as? TransliterationError, .missingAPIKey)
        }
    }

    func testParseSuccess() throws {
        let data = Data(#"{"choices":[{"message":{"role":"assistant","content":"আমি ভাত খাই।"}}]}"#.utf8)
        XCTAssertEqual(try OpenAIClient.parse(data: data, response: response(200)), "আমি ভাত খাই।")
    }

    func testParseErrors() {
        let empty = Data()
        XCTAssertThrowsError(try OpenAIClient.parse(data: empty, response: response(401))) {
            XCTAssertEqual($0 as? TransliterationError, .invalidAPIKey)
        }
        XCTAssertThrowsError(try OpenAIClient.parse(data: empty, response: response(429))) {
            XCTAssertEqual($0 as? TransliterationError, .rateLimited)
        }
        XCTAssertThrowsError(try OpenAIClient.parse(data: empty, response: response(503))) {
            XCTAssertEqual($0 as? TransliterationError, .server(503))
        }
        let bad = Data(#"{"error":{"message":"The model `nope` does not exist"}}"#.utf8)
        XCTAssertThrowsError(try OpenAIClient.parse(data: bad, response: response(404))) {
            XCTAssertEqual($0 as? TransliterationError, .http(404, "The model `nope` does not exist"))
        }
        let blank = Data(#"{"choices":[{"message":{"content":"  "}}]}"#.utf8)
        XCTAssertThrowsError(try OpenAIClient.parse(data: blank, response: response(200))) {
            XCTAssertEqual($0 as? TransliterationError, .emptyResponse)
        }
    }
}

final class ComposerStateTests: XCTestCase {
    func testAIModeTypesIntoSourceAndConverts() {
        var state = ComposerState(mode: .ai)
        for ch in "ami bhat khai" { XCTAssertEqual(state.type(String(ch)), .none) }
        XCTAssertEqual(state.source, "ami bhat khai")
        XCTAssertEqual(state.returnLabel, "Convert")

        guard case let .convert(text, id) = state.returnKey() else { return XCTFail("expected convert") }
        XCTAssertEqual(text, "ami bhat khai")
        XCTAssertEqual(state.phase, .converting)
        XCTAssertEqual(state.type("x"), .none, "typing is ignored while converting")

        state.conversionSucceeded("আমি ভাত খাই।", requestID: id)
        XCTAssertEqual(state.phase, .result)
        XCTAssertEqual(state.returnLabel, "Insert")
        XCTAssertEqual(state.returnKey(), .insert("আমি ভাত খাই।"))
        XCTAssertEqual(state.source, "")
        XCTAssertEqual(state.phase, .composing)
    }

    func testStaleResponsesAreIgnored() {
        var state = ComposerState()
        _ = state.type("ami")
        guard case let .convert(_, id) = state.convert() else { return XCTFail() }
        state.clear()
        state.conversionSucceeded("আমি", requestID: id)
        XCTAssertEqual(state.result, "")
        XCTAssertEqual(state.phase, .composing)
    }

    func testFailureThenRetry() {
        var state = ComposerState()
        _ = state.type("ami")
        guard case let .convert(_, id) = state.convert() else { return XCTFail() }
        state.conversionFailed("boom", requestID: id)
        XCTAssertEqual(state.phase, .error("boom"))
        guard case .convert = state.convert() else { return XCTFail("retry should convert") }
    }

    func testEditingResultByScalars() {
        var state = ComposerState()
        _ = state.type("ami")
        guard case let .convert(_, id) = state.convert() else { return XCTFail() }
        state.conversionSucceeded("আমি", requestID: id)
        state.startEditing()
        XCTAssertEqual(state.displayLanguage, .bangla)
        XCTAssertEqual(state.returnLabel, "Done")

        _ = state.backspace() // removes ি vowel sign only
        XCTAssertEqual(state.result, "আম")
        _ = state.type("া")
        XCTAssertEqual(state.result, "আমা")
        state.moveCursor(by: -10)
        _ = state.type("ত")
        XCTAssertEqual(state.result, "তআমা")
        XCTAssertEqual(state.resultParts.before, "ত")

        XCTAssertEqual(state.returnKey(), .none) // Done
        XCTAssertEqual(state.phase, .result)
        XCTAssertEqual(state.insert(trailingSpace: true), .insert("তআমা "))
    }

    func testTypingAfterResultStartsOver() {
        var state = ComposerState()
        _ = state.type("ami")
        guard case let .convert(_, id) = state.convert() else { return XCTFail() }
        state.conversionSucceeded("আমি", requestID: id)
        _ = state.type(" bhat")
        XCTAssertEqual(state.source, "ami bhat")
        XCTAssertEqual(state.phase, .composing)
        XCTAssertEqual(state.result, "")
    }

    func testBackspaceAndReturnPassThroughWhenEmpty() {
        var state = ComposerState()
        XCTAssertEqual(state.backspace(), .deleteBackward)
        XCTAssertEqual(state.returnKey(), .insert("\n"))
    }

    func testDirectModesTypeIntoHostField() {
        var state = ComposerState(mode: .english)
        XCTAssertEqual(state.type("a"), .insert("a"))
        XCTAssertEqual(state.backspace(), .deleteBackward)
        state.cycleMode()
        XCTAssertEqual(state.mode, .bangla)
        XCTAssertEqual(state.displayLanguage, .bangla)
        XCTAssertEqual(state.type("ক"), .insert("ক"))
        state.cycleMode()
        XCTAssertEqual(state.mode, .ai)
        XCTAssertEqual(state.displayLanguage, .english)
    }

    func testUseFieldTextReplacesOriginalOnInsert() {
        var state = ComposerState()
        guard case let .convert(text, id) = state.useFieldText("Hello\nami bhat khai") else { return XCTFail() }
        XCTAssertEqual(text, "ami bhat khai")
        state.conversionSucceeded("আমি ভাত খাই।", requestID: id)
        XCTAssertEqual(state.insert(trailingSpace: false),
                       .replaceBeforeCursor(deleteCount: 13, text: "আমি ভাত খাই।"))
        XCTAssertEqual(state.useFieldText("line\n   "), .none)
    }
}

final class LivePreviewTests: XCTestCase {
    private func typed(_ text: String) -> ComposerState {
        var state = ComposerState()
        for ch in text { _ = state.type(String(ch)) }
        return state
    }

    func testFreshPreviewInsertsWithoutNetwork() {
        var state = typed("ami bhat khai")
        guard case let .preview(text, id) = state.requestPreview() else { return XCTFail("expected preview") }
        XCTAssertEqual(text, "ami bhat khai")
        XCTAssertEqual(state.requestPreview(), .none, "no duplicate request for the same text")

        state.previewProgress("আমি ভাত", requestID: id)
        XCTAssertFalse(state.isPreviewFresh, "partial preview is not insertable yet")
        XCTAssertEqual(state.returnLabel, "Convert")

        state.previewSucceeded("আমি ভাত খাই।", requestID: id)
        XCTAssertTrue(state.isPreviewFresh)
        XCTAssertEqual(state.returnLabel, "Insert")
        XCTAssertEqual(state.returnKey(), .insert("আমি ভাত খাই।"))
        XCTAssertEqual(state.source, "")
        XCTAssertEqual(state.preview, "")
    }

    func testTypingMakesPreviewStaleAndConvertGoesToNetwork() {
        var state = typed("ami")
        guard case let .preview(_, id) = state.requestPreview() else { return XCTFail() }
        state.previewSucceeded("আমি", requestID: id)
        _ = state.type(" bhat")
        XCTAssertFalse(state.isPreviewFresh)
        XCTAssertEqual(state.preview, "আমি", "stale preview stays visible until the new one arrives")
        guard case .convert(let text, _) = state.convert() else { return XCTFail("stale preview must not be used") }
        XCTAssertEqual(text, "ami bhat")
    }

    func testConvertUsesFreshPreviewInstantly() {
        var state = typed("ami")
        guard case let .preview(_, id) = state.requestPreview() else { return XCTFail() }
        state.previewSucceeded("আমি", requestID: id)
        XCTAssertEqual(state.convert(), .none)
        XCTAssertEqual(state.phase, .result)
        XCTAssertEqual(state.result, "আমি")
    }

    func testEditPreviewOpensEditor() {
        var state = typed("ami")
        guard case let .preview(_, id) = state.requestPreview() else { return XCTFail() }
        state.previewSucceeded("আমি", requestID: id)
        state.editPreview()
        XCTAssertEqual(state.phase, .editing)
        XCTAssertEqual(state.result, "আমি")
    }

    func testSupersededAndClearedPreviewsAreIgnored() {
        var state = typed("ami")
        guard case let .preview(_, first) = state.requestPreview() else { return XCTFail() }
        _ = state.type(" bhat")
        guard case let .preview(_, second) = state.requestPreview() else { return XCTFail() }
        state.previewSucceeded("আমি", requestID: first)
        XCTAssertEqual(state.preview, "", "older request ignored")
        state.previewSucceeded("আমি ভাত", requestID: second)
        XCTAssertTrue(state.isPreviewFresh)

        for _ in 0..<8 { _ = state.backspace() }
        XCTAssertEqual(state.source, "")
        XCTAssertEqual(state.preview, "", "emptying the input clears the preview")
    }

    func testStreamingConversionShowsPartialResult() {
        var state = typed("ami")
        guard case let .convert(_, id) = state.convert() else { return XCTFail() }
        state.conversionProgress("আম", requestID: id)
        XCTAssertEqual(state.result, "আম")
        XCTAssertEqual(state.phase, .converting)
        state.conversionSucceeded("আমি", requestID: id)
        XCTAssertEqual(state.phase, .result)
    }
}

final class StreamParsingTests: XCTestCase {
    func testStreamEvents() {
        XCTAssertEqual(OpenAIClient.streamEvent(fromLine: #"data: {"choices":[{"delta":{"content":"আমি"}}]}"#), .content("আমি"))
        XCTAssertEqual(OpenAIClient.streamEvent(fromLine: "data: [DONE]"), .done)
        XCTAssertNil(OpenAIClient.streamEvent(fromLine: #"data: {"choices":[{"delta":{"role":"assistant"}}]}"#))
        XCTAssertNil(OpenAIClient.streamEvent(fromLine: ": keep-alive"))
    }

    func testStreamRequestFlag() throws {
        let request = try OpenAIClient.makeRequest(input: "ami", apiKey: "k", model: "m", stream: true)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as? [String: Any])
        XCTAssertEqual(json["stream"] as? Bool, true)
        let plain = try OpenAIClient.makeRequest(input: "ami", apiKey: "k", model: "m")
        let plainJSON = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(plain.httpBody)) as? [String: Any])
        XCTAssertNil(plainJSON["stream"])
    }

    func testCleanPartial() {
        XCTAssertEqual(TransliterationPrompt.cleanPartial("\"আমি ভা"), "আমি ভা")
        XCTAssertEqual(TransliterationPrompt.cleanPartial("```\nআমি"), "আমি")
    }
}

final class KeyboardLayoutTests: XCTestCase {
    func testEveryLayoutHasThreeRowsWithBackspace() {
        for language in [KeyboardLanguage.english, .bangla] {
            for layer in [KeyboardLayer.letters, .numbers, .symbols] {
                for shifted in [false, true] {
                    let rows = KeyboardLayouts.rows(language: language, layer: layer, shifted: shifted)
                    XCTAssertEqual(rows.count, 3)
                    XCTAssertEqual(rows[2].last?.action, .backspace)
                    XCTAssertTrue(rows.allSatisfy { $0.count <= 10 }, "\(language) \(layer) row too long")
                    let ids = rows.flatMap { $0.map(\.id) }
                    XCTAssertEqual(Set(ids).count, ids.count, "duplicate keys in \(language) \(layer)")
                }
            }
        }
    }

    func testShiftedEnglishIsUppercase() {
        let rows = KeyboardLayouts.rows(language: .english, layer: .letters, shifted: true)
        XCTAssertEqual(rows[0].first?.label, "Q")
    }

    func testBanglaLayersShareShapeAndHaveHasant() {
        let normal = KeyboardLayouts.rows(language: .bangla, layer: .letters, shifted: false)
        let shifted = KeyboardLayouts.rows(language: .bangla, layer: .letters, shifted: true)
        XCTAssertEqual(normal.map(\.count), shifted.map(\.count))
        XCTAssertTrue(normal.joined().contains { $0.action == .character("্") })
    }
}
