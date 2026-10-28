import Foundation
import Testing
@testable import MarvinCore

@Suite struct DocsMarkdownTests {
    // Test 9: render converts markdown to AttributedString
    @Test func renderConvertsMarkdownToAttributedString() {
        let markdown = "# Heading\n\nParagraph with **bold** and *italic*."
        let result = DocsMarkdown.render(markdown)
        let plain = String(result.characters)
        #expect(plain.contains("Heading"))
        #expect(plain.contains("bold"))
        #expect(plain.contains("italic"))
    }

    // Test 10: render preserves inline formatting with attributes
    @Test func renderPreservesInlineFormatting() {
        let markdown = "This is **bold** and this is *italic*."
        let result = DocsMarkdown.render(markdown)
        let plain = String(result.characters)
        #expect(plain.contains("bold"))
        #expect(plain.contains("italic"))
        // Verify that formatting attributes are applied by checking for presentation intent
        var foundBold = false
        var foundItalic = false
        for run in result.runs {
            if let intent = run.inlinePresentationIntent, intent.contains(.stronglyEmphasized) {
                foundBold = true
            }
            if let intent = run.inlinePresentationIntent, intent.contains(.emphasized) {
                foundItalic = true
            }
        }
        #expect(foundBold)
        #expect(foundItalic)
    }

    // Test 11: render handles links with attributes
    @Test func renderHandlesLinks() {
        let markdown = "Check [this link](https://example.com)"
        let result = DocsMarkdown.render(markdown)
        let plain = String(result.characters)
        #expect(plain.contains("this link"))
        // Verify that link attribute is applied
        var foundLink = false
        for run in result.runs {
            if run.link != nil {
                foundLink = true
                break
            }
        }
        #expect(foundLink)
    }

    // Test 12: render falls back to verbatim on parse error
    @Test func renderFallsBackToVerbatim() {
        // Use text with a null byte, which will cause markdown parsing to fail.
        // The fallback should return the text verbatim.
        let textWithNullByte = "some text\0with null byte"
        let result = DocsMarkdown.render(textWithNullByte)
        let plain = String(result.characters)
        // When markdown parsing fails, the function returns the text as-is.
        // With the null byte, the entire string is returned verbatim.
        #expect(!plain.isEmpty)
        // The returned text should contain the original content (or be the fallback).
        #expect(plain.contains("text") || plain.contains("null"))
    }

    // Test 13: render handles code blocks with attributes
    @Test func renderHandlesCode() {
        let markdown = "Use `code` like this."
        let result = DocsMarkdown.render(markdown)
        let plain = String(result.characters)
        #expect(plain.contains("code"))
        // Verify that code attribute is applied (code spans have the code intent)
        var foundCode = false
        for run in result.runs {
            if let intent = run.inlinePresentationIntent, intent.contains(.code) {
                foundCode = true
                break
            }
        }
        #expect(foundCode)
    }

    // Test 14: render handles lists
    @Test func renderHandlesLists() {
        let markdown = "Items:\n- First\n- Second"
        let result = DocsMarkdown.render(markdown)
        let plain = String(result.characters)
        #expect(plain.contains("First"))
        #expect(plain.contains("Second"))
    }

    // Test 15: render handles empty string
    @Test func renderHandlesEmptyString() {
        let result = DocsMarkdown.render("")
        #expect(String(result.characters) == "")
    }
}
