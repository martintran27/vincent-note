// Run: ./build.sh test
let cases: [(String, String)] = [
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
for (input, expected) in cases {
    let got = Quiz.parseAnswer(input)
    precondition(got == expected, "parseAnswer(\(input.debugDescription)) = \(got), expected \(expected)")
}
print("OK: \(cases.count) cases")
