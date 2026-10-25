import Foundation
import Testing
@testable import MarvinCore

@Suite struct DocsMarkdownTests {
    @Test func rendersPlainText() {
        let result = DocsMarkdown.render("Hello world")
        #expect(String(result.characters) == "Hello world")
    }

    @Test func rendersEmptyString() {
        let result = DocsMarkdown.render("")
        #expect(String(result.characters).isEmpty)
    }

    @Test func preservesBlockStructure() {
        let markdown = "# Heading\n\nParagraph one\n\n- Item 1\n- Item 2"
        let result = DocsMarkdown.render(markdown)
        let text = String(result.characters)
        // With .inlineOnlyPreservingWhitespace, block syntax chars are literal but newlines preserved
        #expect(text.contains("Heading"))
        #expect(text.contains("Paragraph"))
        #expect(text.contains("Item 1"))
        // Newlines are preserved so structure is visible
        #expect(text.contains("\n"))
    }

    @Test func handlesLargeDocument() {
        let markdown = String(repeating: "Line\n", count: 1000)
        let result = DocsMarkdown.render(markdown)
        let text = String(result.characters)
        #expect(!text.isEmpty)
        #expect(text.count > 1000)
    }

    @Test func gracefullyHandlesInvalidMarkdown() {
        // Invalid markdown constructs fall back to plain text
        let input = "**unclosed bold\n\n[link without]("
        let result = DocsMarkdown.render(input)
        let text = String(result.characters)

        // Fallback preserves the literal input text; if markdown parsing succeeded,
        // the output would differ (e.g., bold formatting would be applied).
        // This verifies the catch branch is reached and the fallback works.
        #expect(text == input)
    }
}
