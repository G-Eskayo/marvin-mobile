import Foundation
import Testing
@testable import MarvinCore

@Suite struct QueueModelsTests {
    @Test func queueResponseDecodes() throws {
        let json = """
            {"ok":true,"data":{
             "queue":[
              {"position":1,"repo":"G-Eskayo/marvin","project":"marvin","number":300,"title":"Next task",
               "priority":10,"score":95.5,"machines":["mac-mini-1"],"created_at":"2026-10-25T10:00:00Z"}
             ],
             "running":[
              {"repo":"G-Eskayo/clarity-captions","project":"clarity-captions","number":25,"title":"Latency test",
               "machine":"mac-mini-1"}
             ],
             "error":null
            }}
            """
        let envelope = try JSONDecoder().decode(Envelope<QueueResponse>.self, from: Data(json.utf8))
        let queue = envelope.data!
        #expect(queue.queue.count == 1)
        #expect(queue.queue[0].position == 1)
        #expect(queue.queue[0].number == 300)
        #expect(queue.queue[0].priority == 10)
        #expect(queue.queue[0].machines == ["mac-mini-1"])
        #expect(queue.running.count == 1)
        #expect(queue.running[0].number == 25)
        #expect(queue.error == nil)
    }

    @Test func queueHandlesErrors() throws {
        let json = """
            {"ok":true,"data":{"queue":[],"running":[],"error":"Redis connection failed"}}
            """
        let envelope = try JSONDecoder().decode(Envelope<QueueResponse>.self, from: Data(json.utf8))
        let queue = envelope.data!
        #expect(queue.error == "Redis connection failed")
    }

    @Test func queueRowHasAllFields() throws {
        let json = """
            {"ok":true,"data":{
             "queue":[{
              "position":2,"repo":"G-Eskayo/finance-os","project":"finance-os",
              "number":15,"title":"Add investment tracking",
              "priority":5,"score":72.0,"machines":["mac-mini-1","laptop"],
              "created_at":"2026-10-25T09:30:00Z"
             }],"running":[],"error":null
            }}
            """
        let envelope = try JSONDecoder().decode(Envelope<QueueResponse>.self, from: Data(json.utf8))
        let row = envelope.data!.queue[0]
        #expect(row.position == 2)
        #expect(row.repo == "G-Eskayo/finance-os")
        #expect(row.project == "finance-os")
        #expect(row.number == 15)
        #expect(row.machines.count == 2)
    }
}

private struct Envelope<T: Decodable>: Decodable {
    let ok: Bool
    let data: T?
    let error: String?
}
