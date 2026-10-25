import Foundation
import Testing
@testable import MarvinCore

@Suite struct TicketDetailModelsTests {
    @Test func ticketDetailDecodesAllFields() throws {
        let json = """
            {"ok":true,"data":{
             "number":42,"title":"Fix the bug","body":"Description here",
             "labels":[{"name":"bug"},{"name":"priority:high"}],
             "url":"https://github.com/...", "state":"open",
             "comments":[{"body":"I agree","author":{"login":"alice"},"created_at":"2026-10-25T10:00:00Z"}]
            }}
            """
        let envelope = try JSONDecoder().decode(Envelope<TicketDetail>.self, from: Data(json.utf8))
        let detail = envelope.data!
        #expect(detail.number == 42)
        #expect(detail.title == "Fix the bug")
        #expect(detail.labels.count == 2)
        #expect(detail.labels[0].name == "bug")
        #expect(detail.comments.count == 1)
        #expect(detail.comments[0].author.login == "alice")
    }

    @Test func timelineDecodesEvents() throws {
        let json = """
            {"ok":true,"data":[
             {"stage":"merge","status":"failed","timestamp":"2026-10-25T10:00:00Z",
              "detail":"Merge conflict","machine":"mac-mini-1","cost_usd":0.15},
             {"stage":"verify","status":"passed","timestamp":"2026-10-25T09:00:00Z",
              "detail":null,"machine":null,"cost_usd":0.30}
            ]}
            """
        let envelope = try JSONDecoder().decode(Envelope<[TimelineEvent]>.self, from: Data(json.utf8))
        let events = envelope.data!
        #expect(events.count == 2)
        #expect(events[0].stage == "merge")
        #expect(events[0].status == "failed")
        #expect(events[0].detail == "Merge conflict")
        #expect(events[0].machine == "mac-mini-1")
        #expect(events[0].costUsd == 0.15)
        #expect(events[1].detail == nil)
    }

    @Test func ticketRelationsDecodesAllLists() throws {
        let json = """
            {"ok":true,"data":{
             "tickets":[{"number":40,"repo":"G-Eskayo/marvin","title":"Parent","column":"merge"}],
             "prs":[{"number":500,"repo":"G-Eskayo/marvin","title":"PR title","url":"https://...","is_draft":false}],
             "docs":[{"title":"Design","url":"https://...","kind":"design"}]
            }}
            """
        let envelope = try JSONDecoder().decode(Envelope<TicketRelations>.self, from: Data(json.utf8))
        let relations = envelope.data!
        #expect(relations.tickets.count == 1)
        #expect(relations.tickets[0].column == "merge")
        #expect(relations.prs.count == 1)
        #expect(relations.prs[0].isDraft == false)
        #expect(relations.docs.count == 1)
        #expect(relations.docs[0].kind == "design")
    }

    @Test func replyPlanDetectsWaitingLabel() {
        let plan = ReplyPlan.planReply(labels: ["waiting:approval"], state: nil)
        #expect(plan.requeue == true)
    }

    @Test func replyPlanMarksAsDone() {
        let plan = ReplyPlan.planReply(labels: [], state: "done")
        #expect(plan.add.contains("done"))
        #expect(plan.effect == "Marks as done")
    }

    @Test func replyPlanReopens() {
        let plan = ReplyPlan.planReply(labels: [], state: "open")
        #expect(plan.remove.contains("done"))
        #expect(plan.effect == "Reopens the ticket")
    }
}

private struct Envelope<T: Decodable>: Decodable {
    let ok: Bool
    let data: T?
    let error: String?
}
