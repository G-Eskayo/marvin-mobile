import Foundation

public enum DocsMarkdown {
    /// Renders markdown to AttributedString, preserving block structure and newlines.
    /// Falls back to plain text if markdown parsing fails.
    public static func render(_ markdown: String) -> AttributedString {
        do {
            let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
            return try AttributedString(markdown: markdown, options: options)
        } catch {
            return AttributedString(markdown)
        }
    }
}
