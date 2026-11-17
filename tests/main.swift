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

print("OK: \(answerCases.count + questionCases.count) cases")
