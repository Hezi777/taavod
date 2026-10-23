import Foundation
import Testing
@testable import Taavod

@Test @MainActor func workspaceMigrationIsIdempotentAndPatchesPreserveOtherFields() throws {
    let store = try WorkspaceStore(inMemory: true)
    let profile = WorkspaceRecord(kind: "profile", id: "legacy-owner", payload: ["name": .string("Test learner"), "weeklyHours": .number(4)])
    let job = WorkspaceRecord(kind: "jobs", id: "role", payload: ["status": .string("saved"), "notes": .string("Keep this note"), "url": .string("https://example.org/job?id=12")])
    #expect(try store.importRecords([profile, job]) == 2)
    #expect(try store.importRecords([profile, job]) == 0)
    store.update("profile", id: store.profileID, patch: ["name": .string("New name")])
    #expect(store.list("profile").count == 1)
    #expect(store.profile.number("weeklyHours") == 4)
    store.update("jobs", id: "role", patch: ["status": .string("interviewing")])
    #expect(store.record("jobs", id: "role")?.payload.text("notes") == "Keep this note")
    let roundtrip = try JSONDecoder().decode([WorkspaceRecord].self, from: store.exportData())
    #expect(roundtrip.count == 2)
}

@Test @MainActor func jobIdentityPreservesMeaningfulQueryAndRejectsPrivateNetworks() {
    #expect(JobDiscovery.canonicalURL("https://example.org/job?id=12&utm_source=feed") == "https://example.org/job?id=12")
    #expect(JobDiscovery.canonicalURL("https://www.linkedin.com/jobs/view/123456/?trackingId=x") == "https://www.linkedin.com/jobs/view/123456")
    for address in ["127.0.0.1", "10.0.1.2", "172.16.1.1", "192.168.1.1", "169.254.1.1", "100.64.1.1", "::1", "::ffff:127.0.0.1", "fc00::1", "2001:db8::1"] {
        #expect(PublicJobHTTP.isPublicAddress(address) == false)
    }
    #expect(PublicJobHTTP.isPublicAddress("1.1.1.1"))
    #expect(PublicJobHTTP.isPublicAddress("2606:4700::1111"))
}
