import CoreData
import Foundation
import SwiftData
import Testing
@testable import IronFlow

/// Released schema versions never change: a store written by a released version must keep being
/// recognised as that version, or it can no longer be opened or migrated.
@MainActor
struct SchemaFreezeTests {
    @Test("Every schema version of the migration plan has a frozen fingerprint")
    func everyVersionIsFrozen() {
        #expect(IronFlowMigrationPlan.schemas.count == FrozenSchemaFingerprints.byVersion.count,
                "A new schema version needs its fingerprint recorded in FrozenSchemaFingerprints")
    }

    @Test("Each schema version still writes the store of its released version")
    func versionsMatchTheirFrozenFingerprints() throws {
        for (version, frozen) in zip(IronFlowMigrationPlan.schemas, FrozenSchemaFingerprints.byVersion) {
            let directory = try makeTemporaryDirectory()
            defer { removeTemporaryDirectory(directory) }
            let storeURL = directory.appending(path: "IronFlow.store")
            do {
                let container = try makeStore(of: version, at: storeURL)
                try container.mainContext.save()
            }

            let fingerprint = try storeFingerprint(at: storeURL)
            let changed = Set(fingerprint.keys).union(frozen.keys).filter { fingerprint[$0] != frozen[$0] }.sorted()
            #expect(
                fingerprint == frozen,
                "\(version.versionIdentifier) changed in \(changed). Released models must not change: add a schema version with a migration stage instead. Written: \(fingerprintLiteral(fingerprint))"
            )
        }
    }

    @Test("The app opens its store with the latest released version")
    func currentStoreIsTheLatestVersion() throws {
        let directory = try makeTemporaryDirectory()
        defer { removeTemporaryDirectory(directory) }
        let storeURL = directory.appending(path: "IronFlow.store")
        do {
            let container = try ModelContainerFactory.makePersistent(at: storeURL)
            try container.mainContext.save()
        }

        let latest = try #require(FrozenSchemaFingerprints.byVersion.last)
        let fingerprint = try storeFingerprint(at: storeURL)
        #expect(fingerprint == latest, "Written: \(fingerprintLiteral(fingerprint))")
    }

    @Test("Losing a stored property or relationship of a released model changes its fingerprint")
    func fingerprintDetectsLostPropertiesAndRelationships() throws {
        // The models Core Data builds for version 1 are the ones the stores record: same entities,
        // same hashes. So a hash that changes here is a store that no longer matches the frozen one.
        let model = try #require(NSManagedObjectModel.makeManagedObjectModel(for: SchemaV1.models))
        #expect(Set(model.entitiesByName.keys) == Set(FrozenSchemaFingerprints.v1.keys))
        for (name, entity) in model.entitiesByName {
            #expect(entity.versionHash.base64EncodedString() == FrozenSchemaFingerprints.v1[name], "\(name)")
        }

        // A set's planned load (an attribute of the history) is lost.
        let setLog = try #require(model.entitiesByName["SetLog"])
        let withoutTarget = try #require(setLog.copy() as? NSEntityDescription)
        withoutTarget.properties = withoutTarget.properties.filter { $0.name != "targetWeightKg" }
        #expect(withoutTarget.properties.count == setLog.properties.count - 1)
        #expect(withoutTarget.versionHash != setLog.versionHash)

        // A performed exercise loses the link to its sets (a relationship of the history).
        let performed = try #require(model.entitiesByName["SessionExercise"])
        let withoutSets = try #require(performed.copy() as? NSEntityDescription)
        withoutSets.properties = withoutSets.properties.filter { $0.name != "setLogs" }
        #expect(withoutSets.properties.count == performed.properties.count - 1)
        #expect(withoutSets.versionHash != performed.versionHash)
    }

    @Test("Every record of every released version keeps a unique id")
    func idsStayUnique() throws {
        // Not part of the version hash, so it is checked on its own: duplicate ids would let one record
        // replace another, history included.
        for version in IronFlowMigrationPlan.schemas {
            let model = try #require(NSManagedObjectModel.makeManagedObjectModel(for: version.models))
            for (name, entity) in model.entitiesByName {
                let constraints = entity.uniquenessConstraints.map { $0.compactMap { $0 as? String } }
                #expect(constraints == [["id"]], "\(version.versionIdentifier) \(name): \(constraints)")
            }
        }
    }
}
