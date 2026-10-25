import Foundation
import Testing
@testable import MarvinCore

@Suite struct MrReviewTests {
    // 1. MrPr decodes with all fields
    @Test func mrPrDecodesAllFields() throws {
        let json = #"{"id":"p1","url":"https://github.com/user/repo/pull/1","title":"Feature X","number":123,"repo":"user/repo","author":"dev","status":"pending","createdAt":"2026-10-08T12:00:00Z"}"#
        let pr = try JSONDecoder().decode(MrPr.self, from: json.data(using: .utf8)!)
        #expect(pr.id == "p1")
        #expect(pr.number == 123)
        #expect(pr.title == "Feature X")
        #expect(pr.status == .pending)
    }

    // 2. MrPr tolerates missing optional fields
    @Test func mrPrToleratesmissingOptional() throws {
        let json = #"{"id":"p1","url":"https://github.com/user/repo/pull/1","title":"Feature X","number":123,"repo":"user/repo","status":"pending"}"#
        let pr = try JSONDecoder().decode(MrPr.self, from: json.data(using: .utf8)!)
        #expect(pr.author == nil)
        #expect(pr.createdAt == nil)
    }

    // 3. MrReviewTabStatus decodes all cases
    @Test func statusesDecodeAll() throws {
        let pending = try JSONDecoder().decode(MrReviewTabStatus.self, from: #""pending""#.data(using: .utf8)!)
        let approved = try JSONDecoder().decode(MrReviewTabStatus.self, from: #""approved""#.data(using: .utf8)!)
        let changes = try JSONDecoder().decode(MrReviewTabStatus.self, from: #""changesRequested""#.data(using: .utf8)!)
        #expect(pending == .pending)
        #expect(approved == .approved)
        #expect(changes == .changesRequested)
    }

    // 4. Unknown status decodes as pending
    @Test func unknownStatusDefaultsToPending() throws {
        let unknown = try JSONDecoder().decode(MrReviewTabStatus.self, from: #""unknown""#.data(using: .utf8)!)
        #expect(unknown == .pending)
    }

    // 5. MrReviewStatus decodes counts
    @Test func mrReviewStatusDecodesCounts() throws {
        let json = #"{"open_count":3,"approved_count":2,"changes_requested_count":1}"#
        let status = try JSONDecoder().decode(MrReviewStatus.self, from: json.data(using: .utf8)!)
        #expect(status.openCount == 3)
        #expect(status.approvedCount == 2)
        #expect(status.changesRequestedCount == 1)
    }

    // 6. MrTicketContext decodes with optional fields
    @Test func mrTicketContextDecodes() throws {
        let json = #"{"number":456,"repo":"user/repo","title":"Ticket","current_stage":"executing","current_status":"running"}"#
        let ticket = try JSONDecoder().decode(MrTicketContext.self, from: json.data(using: .utf8)!)
        #expect(ticket.number == 456)
        #expect(ticket.title == "Ticket")
        #expect(ticket.currentStage == "executing")
    }

    // 7. MrTicketContext tolerates missing optional
    @Test func mrTicketContextToleratesmissing() throws {
        let json = #"{"number":456,"repo":"user/repo"}"#
        let ticket = try JSONDecoder().decode(MrTicketContext.self, from: json.data(using: .utf8)!)
        #expect(ticket.title == nil)
        #expect(ticket.currentStage == nil)
    }

    // 8-16: Model and type validation

    // 8. MrActionResult decodes success=true
    @Test func mrActionResultSuccess() throws {
        let json = #"{"success":true,"message":"Approved"}"#
        let result = try JSONDecoder().decode(MrActionResult.self, from: json.data(using: .utf8)!)
        #expect(result.success == true)
        #expect(result.message == "Approved")
    }

    // 9. MrActionResult decodes success=false
    @Test func mrActionResultFailure() throws {
        let json = #"{"success":false,"message":"Error"}"#
        let result = try JSONDecoder().decode(MrActionResult.self, from: json.data(using: .utf8)!)
        #expect(result.success == false)
        #expect(result.message == "Error")
    }

    // 10. MrActionResult with null message
    @Test func mrActionResultNullMessage() throws {
        let json = #"{"success":true,"message":null}"#
        let result = try JSONDecoder().decode(MrActionResult.self, from: json.data(using: .utf8)!)
        #expect(result.success == true)
        #expect(result.message == nil)
    }

    // 11. DenyAction cases exist
    @Test func denyActionChagesRequested() {
        #expect(DenyAction.changesRequested.rawValue == "changesRequested")
    }

    // 12. DenyAction noDecision case
    @Test func denyActionNoDecision() {
        #expect(DenyAction.noDecision.rawValue == "noDecision")
    }

    // 13. DenyAction has exactly 2 cases
    @Test func denyActionCaseCount() {
        #expect(DenyAction.allCases.count == 2)
    }

    // 14. ConfirmedAction stores value
    @Test func confirmedActionValue() {
        let action = ConfirmedAction(value: "test")
        #expect(action.value == "test")
    }

    // 15. ConfirmedAction stores timestamp
    @Test func confirmedActionTimestamp() {
        let now = Date.now
        let action = ConfirmedAction(value: "test", confirmedAt: now)
        #expect(action.confirmedAt == now)
    }

    // 16. ConfirmedAction Equatable
    @Test func confirmedActionEquatable() {
        let a = ConfirmedAction(value: "test", confirmedAt: Date(timeIntervalSince1970: 1000))
        let b = ConfirmedAction(value: "test", confirmedAt: Date(timeIntervalSince1970: 1000))
        #expect(a == b)
    }
}
