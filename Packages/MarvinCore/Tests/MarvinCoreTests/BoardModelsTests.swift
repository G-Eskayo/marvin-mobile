import Foundation
import Testing
@testable import MarvinCore

@Suite struct BoardModelsTests {
    @Test func boardDetailDecodesAllFields() throws {
        let json = """
            {"ok":true,"data":{"repo":"G-Eskayo/marvin","columns":[
             {"id":"todo","label":"To do","cards":[],"archive":false},
             {"id":"done","label":"Done","cards":[],"archive":false}
            ],"other_projects":[],"fetched_at":"2026-10-25T10:30:00Z"}}
            """
        let envelope = try JSONDecoder().decode(Envelope<BoardDetail>.self, from: Data(json.utf8))
        #expect(envelope.data != nil)
        let detail = envelope.data!
        #expect(detail.repo == "G-Eskayo/marvin")
        #expect(detail.columns.count == 2)
        #expect(detail.columns[0].label == "To do")
        #expect(detail.fetchedAt == "2026-10-25T10:30:00Z")
    }

    @Test func cardDecodesAllFields() throws {
        let json = """
            {"ok":true,"data":{"repo":"G-Eskayo/marvin","columns":[
             {"id":"todo","label":"To do","cards":[{
              "id":"c1","number":123,"repo":"G-Eskayo/other","title":"Test card",
              "reason":"Needed for feature","progress":{"done":2,"total":5},
              "evidence":{"verdict":"pass","items":[{"ref":"#workflow-1","detail":"Passed in 45s"}]},
              "blocked_by":[{"number":122,"repo":"G-Eskayo/marvin","title":"Blocker"}],
              "tags":[{"name":"priority:high","kind":"priority"}],
              "pr_links":[{"number":456,"title":"Merge PR","url":"https://github.com/...","is_draft":false,"has_dev_evidence":true}]
             }],"archive":false}
            ],"other_projects":[],"fetched_at":"2026-10-25T10:30:00Z"}}
            """
        let envelope = try JSONDecoder().decode(Envelope<BoardDetail>.self, from: Data(json.utf8))
        let card = envelope.data!.columns[0].cards[0]
        #expect(card.number == 123)
        #expect(card.repo == "G-Eskayo/other")
        #expect(card.title == "Test card")
        #expect(card.progress?.done == 2)
        #expect(card.progress?.total == 5)
        #expect(card.evidence?.verdict == "pass")
        #expect(card.evidence?.items?.first?.ref == "#workflow-1")
        #expect(card.blockedBy?.first?.number == 122)
        #expect(card.tags?.first?.name == "priority:high")
        #expect(card.tags?.first?.kind == .priority)
        #expect(card.prLinks?.first?.isDraft == false)
        #expect(card.prLinks?.first?.hasDevEvidence == true)
    }

    @Test func cardToleratesMissingOptionalFields() throws {
        let json = """
            {"ok":true,"data":{"repo":"G-Eskayo/marvin","columns":[
             {"id":"todo","label":"To do","cards":[{
              "id":"c1","number":123,"title":"Minimal card"
             }],"archive":false}
            ],"other_projects":[],"fetched_at":"2026-10-25T10:30:00Z"}}
            """
        let envelope = try JSONDecoder().decode(Envelope<BoardDetail>.self, from: Data(json.utf8))
        let card = envelope.data!.columns[0].cards[0]
        #expect(card.number == 123)
        #expect(card.repo == nil)
        #expect(card.reason == nil)
        #expect(card.progress == nil)
    }

    @Test func unknownTagKindDecodesAsOther() throws {
        let json = """
            {"ok":true,"data":{"repo":"G-Eskayo/marvin","columns":[
             {"id":"todo","label":"To do","cards":[{
              "id":"c1","number":123,"title":"Card","tags":[{"name":"custom","kind":"unknown"}]
             }],"archive":false}
            ],"other_projects":[],"fetched_at":"2026-10-25T10:30:00Z"}}
            """
        let envelope = try JSONDecoder().decode(Envelope<BoardDetail>.self, from: Data(json.utf8))
        let tag = envelope.data!.columns[0].cards[0].tags![0]
        #expect(tag.kind == .other)
    }

    @Test func otherProjectsDecodeWithOptionalFields() throws {
        let json = """
            {"ok":true,"data":{"repo":"G-Eskayo/marvin","columns":[],
             "other_projects":[
              {"project_id":"clarity-captions","count":3,"repo":"G-Eskayo/clarity-captions","name":"clarity-captions"},
              {"project_id":"unknown","count":1}
             ],"fetched_at":"2026-10-25T10:30:00Z"}}
            """
        let envelope = try JSONDecoder().decode(Envelope<BoardDetail>.self, from: Data(json.utf8))
        let others = envelope.data!.otherProjects
        #expect(others.count == 2)
        #expect(others[0].count == 3)
        #expect(others[0].repo == "G-Eskayo/clarity-captions")
        #expect(others[1].repo == nil)
    }

    @Test func boardColumnIsIdentifiable() throws {
        let json = """
            {"ok":true,"data":{"repo":"G-Eskayo/marvin","columns":[
             {"id":"unique-col","label":"Test","cards":[]}
            ],"other_projects":[],"fetched_at":"2026-10-25T10:30:00Z"}}
            """
        let envelope = try JSONDecoder().decode(Envelope<BoardDetail>.self, from: Data(json.utf8))
        let col = envelope.data!.columns[0]
        #expect(col.id == "unique-col")
    }
}

private struct Envelope<T: Decodable>: Decodable {
    let ok: Bool
    let data: T?
    let error: String?
}
