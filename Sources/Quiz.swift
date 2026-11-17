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

    private static let optionMarker = try! NSRegularExpression(pattern: "(?<![A-Za-z0-9])([ABCD])\\s?[.):]")
    private static let minOptionMarkers = 2

    /// Cheap pre-check before spending ~10s of model time: at least two distinct option
    /// markers like "A." / "B)" must appear. ponytail: quizzes whose options carry no letters
    /// get an instant "?"; loosen this check if such a source turns up.
    static func looksLikeQuestion(_ text: String) -> Bool {
        let range = NSRange(text.startIndex..., in: text)
        let letters = Set(optionMarker.matches(in: text, range: range).compactMap {
            Range($0.range(at: 1), in: text).map { text[$0] }
        })
        return letters.count >= minOptionMarkers
    }

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
