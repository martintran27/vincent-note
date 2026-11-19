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

    /// Free-form (tự luận) answers, two kinds decided by the model itself:
    /// - accounting problems for the English-taught Accounting Principles course (Wild; US GAAP),
    ///   laid out like the lecturer's answer keys (tested on the chapter 5 key: journal fully right);
    /// - management (Quản trị học) and other theory questions, written like a good student in plain
    ///   B1-level wording, one sentence per line, avoiding the usual chatbot tells.
    static let essaySystemPrompt = """
    You help a university student review for exams. The question text comes from OCR of a screenshot, \
    so expect small recognition errors. Answer in the same language as the question, plain text only \
    (no markdown, no tables, no bold, no bullet symbols, no headings). Complete every requested part, \
    labeled (1), (2), (3) as in the question. First decide which kind of question it is.

    KIND A, accounting problems (journal entries, adjusting, closing, inventory costing, ...). \
    Course: English-taught Accounting Principles (textbook: Wild, Kwok, Venkatesh & Shaw, \
    Fundamental Accounting Principles; US GAAP; sole proprietorship with Owner's Capital and \
    Owner's Withdrawal; perpetual inventory system and gross method unless the problem says otherwise).
    Write it exactly the way the lecturer writes answer keys:
    - Start each transaction with its date and a short restatement, e.g. \
    "December 10. Sold merchandise to Osimi Company for $28,000 on credit", then its entry below.
    - Each entry line is "Dr. <account> $<amount>" or "Cr. <account> $<amount>", Debit lines before \
    Credit lines, every amount in full with the dollar sign and commas, no abbreviations like 28k.
    - A sale with a cost: two blocks, "+ Recognize revenue" then its entry, \
    "+ Recognize cost of goods sold" then its entry.
    - Closing entries: four blocks "+ Closing revenue", "+ Closing expense", \
    "+ Closing income summary", "+ Closing withdrawal" (use $0 when there are no withdrawals).
    - Show a calculation on one line before its entry, e.g. \
    "Dep = (Asset cost - Salvage value)/ Useful life = ($26,000 - $2,000)/48 = $500" or \
    "COGS of January 12 = 120 units x $5 + 30 units x $6 = $780".
    - Account titles as the lecturer uses them: Cash, Account receivable, Merchandise inventory, \
    Office supplies, Supplies, Prepaid rent, Office equipment, Account payable, Unearned service revenue, \
    Owner's Capital, Owner's Withdrawal, Sale revenue, Service revenue, Sale discounts, \
    Sale return and allowance, Cost of goods sold, Rent expense, Supplies expense, \
    Depreciation expense, Accumulated depreciation, Income summary.
    Accounting rules:
    - Buyer paying within the discount period: Dr. Account payable (full) / Cr. Merchandise inventory \
    (discount) / Cr. Cash (net). Seller receiving within it: Dr. Cash (net), Dr. Sale discounts / \
    Cr. Account receivable (full). Customer return on account: Dr. Sale return and allowance / \
    Cr. Account receivable, and Dr. Merchandise inventory / Cr. Cost of goods sold at cost.
    - Adjusting: supplies used = balance on hand before the count - count → Dr. Supplies expense / \
    Cr. Supplies. Unearned revenue earned → Dr. Unearned service revenue / Cr. Service revenue. \
    Prepaid expense used → Dr. expense / Cr. prepaid. Monthly straight-line depreciation → \
    Dr. Depreciation expense / Cr. Accumulated depreciation.
    - Closing: Dr. each revenue / Cr. Income summary; Dr. Income summary / Cr. each expense \
    (Cost of goods sold and all adjusted expenses included); Dr. Income summary / Cr. Owner's Capital \
    for net income; Dr. Owner's Capital / Cr. Owner's Withdrawal.
    - Inventory costing: FIFO; average continuous recomputed after each purchase; average periodic = \
    total cost of beginning + all purchases / total units, applied to every sale.

    KIND B, management (Principles of Management / Quản trị học) and any other theory question. \
    Write the answer the way a good student writes it by hand in an exam, not like a chatbot:
    - One sentence per line. Sentences of about 8 to 18 words.
    - Length follows the question: "define / what is" needs 2 to 4 sentences; \
    "explain / describe / discuss / analyze / compare" needs about 6 to 12 sentences; \
    a question with several parts answers each part in turn. When marks are shown, write about \
    2 to 3 sentences per mark.
    - Open with a sentence that answers the question directly. No introduction about the topic, \
    no restating the question, no closing summary.
    - Use the course's key terms (for example planning, organizing, leading, controlling, \
    SWOT, motivation, Maslow, span of control, centralization), and explain each in plain words.
    - Exam questions usually come with a case (a company, people, numbers). Then build every point \
    on that case: use its names and its facts as the examples, say what the people in it should do, \
    and do not bring in outside examples. Only when there is no case, give one short example with a \
    simple made-up business such as a coffee chain with ten shops.
    - Never state facts about real, named companies that are not in the question, because they may be wrong.
    - English answers use B1-level vocabulary or easier: common words, simple grammar, \
    simple linking words like and, but, so, because, also, for example, first, then.
    - Vietnamese answers use plain everyday Vietnamese, like a student explaining to a friend.
    - Never use these words or patterns: delve, crucial, pivotal, vital, essential, leverage, foster, \
    robust, seamless, landscape, realm, tapestry, navigate, empower, holistic, synergy, paradigm, \
    furthermore, moreover, additionally, in conclusion, overall, ultimately, it is important to note, \
    plays a key role, in today's world, not only ... but also, dashes as punctuation, rhetorical \
    questions, lists of exactly three adjectives, exclamation marks.

    If the text is not a question or problem to answer, reply with exactly ?
    """

    /// Fewer non-space characters than this is stray UI text, not an exercise.
    private static let minEssayCharacters = 15

    static func hasEnoughText(_ text: String) -> Bool {
        text.filter { !$0.isWhitespace }.count >= minEssayCharacters
    }

    private static let markdownNoise = try! NSRegularExpression(pattern: "(?m)^#{1,6}\\s*|\\*\\*|__|`|^[ \\t]*[-•*][ \\t]+")
    /// Em dashes are a typical AI tell; a comma reads like a student wrote it.
    private static let emDash = try! NSRegularExpression(pattern: "\\s*—\\s*")

    /// Plain text for the solution display; nil when the model declined ("?") or said nothing.
    static func cleanEssay(_ reply: String) -> String? {
        let answerPart = reply.components(separatedBy: "</think>").last ?? reply
        let noMarkdown = markdownNoise.stringByReplacingMatches(
            in: answerPart, range: NSRange(answerPart.startIndex..., in: answerPart), withTemplate: "")
        let plain = emDash.stringByReplacingMatches(
            in: noMarkdown, range: NSRange(noMarkdown.startIndex..., in: noMarkdown), withTemplate: ", ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return plain.isEmpty || plain == unsure ? nil : plain
    }

    private static let entryLine = try! NSRegularExpression(
        pattern: "^\\s*([DdCc])r\\.?\\s+(.+?)\\s*:?\\s+\\$(.*)$")
    private static let dateHeader = try! NSRegularExpression(
        pattern: "^(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\\.?\\s+(\\d{1,2})\\b")
    private static let accountShortNames: [(NSRegularExpression, String)] = [
        ("accounts? receivable", "A/R"), ("accounts? payable", "A/P"), ("cost of goods sold", "COGS"),
        ("merchandise inventory", "Merchandise"), ("accumulated depreciation", "Accum. depreciation"),
    ].map { (try! NSRegularExpression(pattern: "\\b\($0.0)\\b", options: .caseInsensitive), $0.1) }
    /// "+ Recognize revenue" is implied by the entry itself; the cost half gets a short tag.
    private static let tagShortNames = ["recognize revenue": "", "recognize cost of goods sold": "COGS"]

    private static let bareTaskLabel = try! NSRegularExpression(pattern: "^\\(?\\d{1,2}\\)\\.?$")

    /// One short line per step for the single-line display: each journal entry becomes
    /// "Dec 10  Dr A/R 28,000 · Cr Sale revenue 28,000"; calculations and other text stay as their own lines.
    /// A date header labels the entries right after it; any other line ends that group.
    /// A bare part label like "(2)" is not a step of its own: it prefixes the next one.
    static func compactSteps(_ text: String) -> [String] {
        var steps: [String] = []
        var date: String?
        var tag: String?
        var partLabel: String?
        var debits: [String] = []
        var credits: [String] = []

        func emit(_ step: String) {
            steps.append(partLabel.map { $0 + " " + step } ?? step)
            partLabel = nil
        }

        func flush() {
            guard !debits.isEmpty || !credits.isEmpty else { return }
            let prefix = [date, tag].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")
            let body = (debits + credits).joined(separator: " · ")
            emit(prefix.isEmpty ? body : prefix + "  " + body)
            debits = []
            credits = []
            tag = nil
        }

        for raw in text.components(separatedBy: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }
            let range = NSRange(line.startIndex..., in: line)
            if let match = entryLine.firstMatch(in: line, range: range),
               let side = Range(match.range(at: 1), in: line),
               let account = Range(match.range(at: 2), in: line),
               let amount = Range(match.range(at: 3), in: line) {
                let isCredit = line[side].lowercased() == "c"
                if !isCredit && !credits.isEmpty { flush() } // a new Dr after credits starts the next entry
                let item = (isCredit ? "Cr " : "Dr ") + shortAccount(String(line[account])) + " " + line[amount]
                if isCredit { credits.append(item) } else { debits.append(item) }
            } else if line.hasPrefix("+") {
                flush()
                let name = line.dropFirst().trimmingCharacters(in: .whitespaces)
                tag = tagShortNames[name.lowercased()] ?? name
            } else if let match = dateHeader.firstMatch(in: line, range: range),
                      let month = Range(match.range(at: 1), in: line),
                      let day = Range(match.range(at: 2), in: line) {
                flush()
                date = line[month] + " " + line[day]
            } else if bareTaskLabel.firstMatch(in: line, range: range) != nil {
                flush()
                date = nil
                partLabel = partLabel.map { $0 + " " + line } ?? line
            } else {
                flush()
                date = nil
                emit(line)
            }
        }
        flush()
        if let partLabel { steps.append(partLabel) } // a trailing label with nothing after it
        return steps.flatMap { wrap($0, separators: wrapSeparators) }
    }

    /// Longest step the one-line display shows without truncating (about its width at 13 pt).
    static let maxStepLength = 90
    /// Where a long step may be cut, best first: between accounts, sentences, clauses, then words.
    /// `kept` stays at the end of the left piece; the rest of the separator is dropped at the cut.
    private static let wrapSeparators: [(separator: String, kept: String)] = [
        (" · ", ""), (". ", "."), ("; ", ";"), (", ", ","), (" ", ""),
    ]

    private static func wrap(_ step: String, separators: ArraySlice<(separator: String, kept: String)>) -> [String] {
        guard step.count > maxStepLength else { return [step] }
        guard let (separator, kept) = separators.first else { // one huge word: hard cut
            return stride(from: 0, to: step.count, by: maxStepLength).map {
                String(step.dropFirst($0).prefix(maxStepLength))
            }
        }
        let parts = step.components(separatedBy: separator)
        guard parts.count > 1 else { return wrap(step, separators: separators.dropFirst()) }
        var pieces: [String] = []
        var current = parts[0]
        for part in parts.dropFirst() {
            let joined = current + separator + part
            if joined.count + kept.count <= maxStepLength {
                current = joined
            } else {
                pieces.append(current + kept)
                current = part
            }
        }
        pieces.append(current)
        return pieces.flatMap { wrap($0, separators: separators.dropFirst()) }
    }

    private static func wrap(_ step: String, separators: [(separator: String, kept: String)]) -> [String] {
        wrap(step, separators: separators[...])
    }

    private static func shortAccount(_ name: String) -> String {
        accountShortNames.reduce(name) { result, pair in
            pair.0.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result),
                                            withTemplate: pair.1)
        }
    }

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
