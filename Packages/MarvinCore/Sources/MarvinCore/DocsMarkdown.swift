import Foundation

/// Renders markdown text as AttributedString with inline formatting (bold, italic, links, code).
public enum DocsMarkdown {
    public static func render(_ text: String) -> AttributedString {
        guard !text.isEmpty else { return AttributedString("") }
        do {
            var options = AttributedString.MarkdownParsingOptions()
            options.interpretedSyntax = .inlineOnlyPreservingWhitespace
            return try AttributedString(markdown: text, options: options)
        } catch {
            return AttributedString(text)
        }
    }
}
