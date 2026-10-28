import Foundation
import Testing
@testable import MarvinCore

@Suite struct DocsModelsTests {
    // Test 1: DocsRepo decodes correctly
    @Test func docsRepoDecodesFromJSON() throws {
        let json = #"{"id":"__master__","name":"Master Documentation","description":"Central docs repository"}"#
        let repo = try JSONDecoder().decode(DocsRepo.self, from: Data(json.utf8))
        #expect(repo.id == "__master__")
        #expect(repo.name == "Master Documentation")
        #expect(repo.description == "Central docs repository")
    }

    // Test 2: DocsRepo is Identifiable via id
    @Test func docsRepoIsIdentifiable() throws {
        let json = #"{"id":"test-repo","name":"Test","description":"Test docs"}"#
        let repo = try JSONDecoder().decode(DocsRepo.self, from: Data(json.utf8))
        #expect(repo.id == "test-repo")
    }

    // Test 3: DocsRepos decodes with generatedAt (camelCase from snake_case)
    @Test func docsReposDecodesGeneratedAt() throws {
        let json = #"{"generated_at":"2026-10-25T12:34:56Z","repos":[{"id":"__master__","name":"Master","description":"Docs"}]}"#
        let repos = try JSONDecoder().decode(DocsRepos.self, from: Data(json.utf8))
        #expect(repos.generatedAt == "2026-10-25T12:34:56Z")
        #expect(repos.repos.count == 1)
    }

    // Test 4: DocsRepos handles empty repos
    @Test func docsReposHandlesEmptyRepos() throws {
        let json = #"{"generated_at":"2026-10-25T12:34:56Z","repos":[]}"#
        let repos = try JSONDecoder().decode(DocsRepos.self, from: Data(json.utf8))
        #expect(repos.repos.isEmpty)
    }

    // Test 5: DocsTreeEntry decodes and is Identifiable by path
    @Test func docsTreeEntryDecodesAndIsIdentifiable() throws {
        let json = #"{"path":"CONTEXT.md","type":"file","name":"CONTEXT.md"}"#
        let entry = try JSONDecoder().decode(DocsTreeEntry.self, from: Data(json.utf8))
        #expect(entry.path == "CONTEXT.md")
        #expect(entry.id == "CONTEXT.md")
        #expect(entry.type == "file")
    }

    // Test 6: DocsTreeEntry handles directories
    @Test func docsTreeEntryHandlesDirectories() throws {
        let json = #"{"path":"docs","type":"dir","name":"docs"}"#
        let entry = try JSONDecoder().decode(DocsTreeEntry.self, from: Data(json.utf8))
        #expect(entry.type == "dir")
    }

    // Test 7: DocsTree decodes with entries (renamed from tree)
    @Test func docsTreeDecodesWithEntries() throws {
        let json = #"{"tree":[{"path":"CONTEXT.md","type":"file","name":"CONTEXT.md"},{"path":"adr","type":"dir","name":"adr"}]}"#
        let tree = try JSONDecoder().decode(DocsTree.self, from: Data(json.utf8))
        #expect(tree.entries.count == 2)
        #expect(tree.entries[0].path == "CONTEXT.md")
        #expect(tree.entries[1].path == "adr")
    }

    // Test 8: DocsTree handles empty tree
    @Test func docsTreeHandlesEmptyTree() throws {
        let json = #"{"tree":[]}"#
        let tree = try JSONDecoder().decode(DocsTree.self, from: Data(json.utf8))
        #expect(tree.entries.isEmpty)
    }

    // Test 8a: DocsRepo handles missing optional fields
    @Test func docsRepoHandlesOptionalFields() throws {
        let json = #"{"id":"minimal-repo"}"#
        let repo = try JSONDecoder().decode(DocsRepo.self, from: Data(json.utf8))
        #expect(repo.id == "minimal-repo")
        #expect(repo.name == nil)
        #expect(repo.description == nil)
        #expect(repo.kind == nil)
        #expect(repo.status == nil)
        #expect(repo.local == nil)
    }

    // Test 8b: DocsRepos with repo missing name still decodes
    @Test func docsReposHandlesRepoWithoutName() throws {
        let json = #"{"generated_at":"2026-10-25T12:00:00Z","repos":[{"id":"no-name-repo","description":"A repo without name"}]}"#
        let repos = try JSONDecoder().decode(DocsRepos.self, from: Data(json.utf8))
        #expect(repos.repos.count == 1)
        #expect(repos.repos[0].id == "no-name-repo")
        #expect(repos.repos[0].name == nil)
    }
}
