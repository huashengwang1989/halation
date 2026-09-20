import SwiftUI

/// Text whose backticked spans are set in a monospaced face.
///
/// File names and identifiers read badly in a proportional face — `minimax_h3_`
/// loses its underscores against the surrounding prose, and a long name is hard
/// to tell apart from the sentence carrying it. Messages that name a file wrap it
/// in backticks and come through here.
///
/// The monospaced font is applied explicitly rather than left to Markdown's own
/// code styling, so the result does not depend on how a given OS chooses to
/// render `inlinePresentationIntent`.
struct CodeSpanText: View {
    let string: String

    init(_ string: String) { self.string = string }

    var body: some View {
        Text(attributed)
    }

    private var attributed: AttributedString {
        guard var text = try? AttributedString(
            markdown: string,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))
        else { return AttributedString(string) }

        for run in text.runs where run.inlinePresentationIntent?.contains(.code) == true {
            text[run.range].font = .system(.callout, design: .monospaced)
        }
        return text
    }
}
