// Run: ./build.sh test

// parseAnswer: model reply → letter
let answerCases: [(String, String)] = [
    ("B", "B"),
    ("  C\n", "C"),
    ("D.", "D"),
    ("Đáp án: A", "A"),
    ("The answer is B", "B"),
    ("<think>maybe A or C</think>\nC", "C"),
    ("?", "?"),
    ("", "?"),
    ("không đọc được câu hỏi", "?"),
    ("ABC", "?"),
]
for (input, expected) in answerCases {
    let got = Quiz.parseAnswer(input)
    precondition(got == expected, "parseAnswer(\(input.debugDescription)) = \(got), expected \(expected)")
}

// looksLikeQuestion: OCR text → worth asking the model?
let questionCases: [(String, Bool)] = [
    ("Câu 2: HTTPS dùng cổng nào?\nA. 21\nB. 80\nC. 443\nD. 8080", true),
    ("Which planet?\nA) Venus\nB) Mars", true),
    ("Câu 1: ...? A. 1945 B. 1954 C. 1968 D. 1975", true), // OCR merged options onto one line
    ("TUA DUYEN CHUNG TA PHAI NHAT\n~ SAC HUONG PHAI TAN ~", false),
    ("Chapter A. Introduction", false), // a single marker is not a question
    ("", false),
]
for (input, expected) in questionCases {
    let got = Quiz.looksLikeQuestion(input)
    precondition(got == expected, "looksLikeQuestion(\(input.debugDescription)) = \(got), expected \(expected)")
}

// cleanEssay: model reply → plain text for the gray panel, nil when there is nothing to show
let essayCases: [(String, String?)] = [
    ("1) Nợ TK 111 / Có TK 112: 15.000.000", "1) Nợ TK 111 / Có TK 112: 15.000.000"),
    ("<think>nháp</think>\n  Kết quả: 2.650.000  \n", "Kết quả: 2.650.000"),
    ("## Lời giải\n**Nợ 621** / Có 152: `12.000.000`", "Lời giải\nNợ 621 / Có 152: 12.000.000"),
    ("?", nil),
    ("   \n", nil),
    ("- Planning sets goals — it comes first.\n• Organizing groups the work.", "Planning sets goals, it comes first.\nOrganizing groups the work."),
]
for (input, expected) in essayCases {
    let got = Quiz.cleanEssay(input)
    precondition(got == expected, "cleanEssay(\(input.debugDescription)) = \(String(describing: got)), expected \(String(describing: expected))")
}

// compactSteps: teacher-style solution → one short line per entry / calculation
let teacherStyle = """
(1)
December 1. Purchased $20,000 of merchandise from the Graint Store on cash.
Dr. Merchandise Inventory $20,000
    Cr. Cash $20,000
December 10. Sold merchandise to Osimi Company for $28,000 on credit.
+ Recognize revenue
Dr. Accounts Receivable $28,000
    Cr. Sale revenue $28,000
+ Recognize cost of goods sold
Dr. Cost of Goods Sold $20,000
    Cr. Merchandise Inventory $20,000
January 8
Dr. Account payable $15,000
Cr. Cash $14,700
Cr. Merchandise inventory $300
Dep = ($26,000 - $2,000)/48 = $500
+ Closing revenue
Dr. Service revenue $33,000
Cr. Income summary $33,000
"""
let expectedSteps = [
    "(1) Dec 1  Dr Merchandise 20,000 · Cr Cash 20,000", // a bare part label joins the next step
    "Dec 10  Dr A/R 28,000 · Cr Sale revenue 28,000",
    "Dec 10 COGS  Dr COGS 20,000 · Cr Merchandise 20,000",
    "Jan 8  Dr A/P 15,000 · Cr Cash 14,700 · Cr Merchandise 300",
    "Dep = ($26,000 - $2,000)/48 = $500",
    "Closing revenue  Dr Service revenue 33,000 · Cr Income summary 33,000",
]
let steps = Quiz.compactSteps(teacherStyle)
precondition(steps == expectedSteps, "compactSteps =\n\(steps.joined(separator: "\n"))")
precondition(Quiz.compactSteps("Trình bày nguyên tắc giá gốc.\nTài sản ghi theo giá gốc.") ==
             ["Trình bày nguyên tắc giá gốc.", "Tài sản ghi theo giá gốc."], "plain text lines stay as steps")

// long lines are wrapped into several steps of at most Quiz.maxStepLength characters
let theory = "The matching principle requires that expenses be recorded in the same period as the revenues they help to produce. This makes net income for each period meaningful, because costs and benefits are compared fairly."
let theorySteps = Quiz.compactSteps(theory)
precondition(theorySteps.count >= 2, "a long paragraph becomes several steps")
precondition(theorySteps.allSatisfy { $0.count <= Quiz.maxStepLength }, "no step is longer than the limit")
precondition(theorySteps.joined(separator: " ") == theory, "wrapping keeps every word, in order")
let longClosing = "+ Closing expense\nDr. Income summary $20,500\nCr. Cost of goods sold $18,000\nCr. Supplies expense $2,000\nCr. Depreciation expense $500\nCr. Rent expense $1,000\nCr. Utilities expense $300"
let closingSteps = Quiz.compactSteps(longClosing)
precondition(closingSteps.count >= 2 && closingSteps.allSatisfy { $0.count <= Quiz.maxStepLength },
             "a long entry is cut between accounts:\n\(closingSteps.joined(separator: "\n"))")
precondition(closingSteps.dropFirst().allSatisfy { $0.hasPrefix("Cr ") || $0.hasPrefix("Dr ") },
             "continuation lines start at an account, never mid-amount")

// hasEnoughText: OCR text long enough to be an essay prompt?
precondition(Quiz.hasEnoughText("Trình bày nguyên tắc giá gốc trong kế toán."), "a short essay prompt counts")
precondition(!Quiz.hasEnoughText("  ok \n"), "a few stray characters do not")

let tableCases: Int = answerCases.count + questionCases.count + essayCases.count
let singleChecks = 9 // compactSteps 2 + wrapping 5 + hasEnoughText 2
print("OK: \(tableCases + singleChecks) checks")
