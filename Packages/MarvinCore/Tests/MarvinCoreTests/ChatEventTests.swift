import Foundation
import Testing
@testable import MarvinCore

// The backend streams /chat replies as NDJSON lines of normalised events
// (mobile-backend/session_runner.js normaliseEvent).
@Suite struct ChatEventTests {
    @Test func decodesEachEventType() {
        #expect(ChatEvent(line: #"{"type":"session","sessionId":"s1"}"#) == .session(id: "s1"))
        #expect(ChatEvent(line: #"{"type":"text","text":"Hi"}"#) == .text("Hi"))
        #expect(ChatEvent(line: #"{"type":"tool_use","name":"Bash","input":{"command":"ls"}}"#) == .toolUse(name: "Bash"))
        #expect(ChatEvent(line: #"{"type":"result","text":"Hi","sessionId":"s1","costUsd":0.01,"durationMs":900,"isError":false}"#)
            == .result(text: "Hi", sessionId: "s1", isError: false))
        #expect(ChatEvent(line: #"{"type":"error","message":"claude exited with code 1"}"#) == .error("claude exited with code 1"))
    }

    @Test func skipsBlankMalformedAndUnknownLines() {
        #expect(ChatEvent(line: "") == nil)
        #expect(ChatEvent(line: "not json") == nil)
        #expect(ChatEvent(line: #"{"type":"something_new"}"#) == nil)
    }
}

@Suite struct ReplyAccumulatorTests {
    @Test func joinsStreamedTextIntoTheReply() {
        var reply = ReplyAccumulator()
        reply.apply(.session(id: "s1"))
        reply.apply(.text("Good "))
        reply.apply(.text("morning"))
        #expect(reply.text == "Good morning")
        #expect(!reply.isFinished)
        reply.apply(.result(text: "Good morning", sessionId: "s1", isError: false))
        #expect(reply.text == "Good morning")
        #expect(reply.isFinished)
        #expect(reply.error == nil)
    }

    @Test func fallsBackToTheResultTextWhenNothingStreamed() {
        var reply = ReplyAccumulator()
        reply.apply(.result(text: "Done.", sessionId: "s1", isError: false))
        #expect(reply.text == "Done.")
    }

    @Test func recordsErrors() {
        var reply = ReplyAccumulator()
        reply.apply(.error("claude exited with code 1"))
        #expect(reply.error == "claude exited with code 1")
        #expect(reply.isFinished)
    }

    @Test func aFailedResultIsAnError() {
        var reply = ReplyAccumulator()
        reply.apply(.result(text: "Usage limit reached", sessionId: "s1", isError: true))
        #expect(reply.error == "Usage limit reached")
    }
}
