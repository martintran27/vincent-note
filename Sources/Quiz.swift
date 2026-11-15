import Foundation

/// Model + prompt + answer parsing. Kept free of AppKit so tests/main.swift can compile it alone.
enum Quiz {
    static let model = "qwen3:30b-a3b-thinking-2507-q4_K_M"
    static let keepAlive = "30m"
    static let unsure = "?"

    static let systemPrompt = """
    You answer multiple-choice quiz questions written in Vietnamese or English. \
    The text comes from OCR of a screenshot, so expect small recognition errors. \
    Exactly one option (A, B, C or D) is correct. \
    Reply with ONLY that single letter and nothing else. \
    If the text is not a readable multiple-choice question, reply with ?
    """

    private static let letterPattern = try! NSRegularExpression(pattern: "(?<![A-Za-z])[ABCD](?![A-Za-z])")

    /// Final answer letter from a model reply; "?" when no A–D can be found.
    static func parseAnswer(_ reply: String) -> String {
        // Some models inline their reasoning; only the text after </think> is the answer.
        let answerPart = reply.components(separatedBy: "</think>").last ?? reply
        let text = answerPart.trimmingCharacters(in: .whitespacesAndNewlines)
        let range = NSRange(text.startIndex..., in: text)
        guard let match = letterPattern.matches(in: text, range: range).last,
              let letter = Range(match.range, in: text) else { return unsure }
        return String(text[letter])
    }
}
