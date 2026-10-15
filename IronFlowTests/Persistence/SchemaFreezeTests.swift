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
            // Every entity written or frozen is compared, so this is as strict as comparing the whole
            // fingerprints; a difference is reported in one short line per entity, with the written value.
            for name in Set(fingerprint.keys).union(frozen.keys).sorted() {
                #expect(
                    fingerprint[name] == frozen[name],
                    "\(version.versionIdentifier) \(name): written \(fingerprint[name] ?? "nil"). Released models must not change: add a schema version with a migration stage instead."
                )
            }
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
        let model = try #require(NSManagedObjectModel.makeManagedObjectModel(for: SchemaV1.models))

        // Control: the whole model copied without a change keeps the frozen fingerprints, so a
        // different fingerprint below comes from the change alone, not from the copy.
        let setLogControl = try fingerprint(of: "SetLog", inCopyOf: model)
        #expect(setLogControl == FrozenSchemaFingerprints.v1["SetLog"])
        let performedControl = try fingerprint(of: "SessionExercise", inCopyOf: model)
        #expect(performedControl == FrozenSchemaFingerprints.v1["SessionExercise"])

        // A set's planned load (an attribute of the history) is lost.
        let withoutTarget = try fingerprint(of: "SetLog", inCopyOf: model) { entity in
            let count = entity.properties.count
            #expect(entity.attributesByName["targetWeightKg"] != nil)
            entity.properties = entity.properties.filter { $0.name != "targetWeightKg" }
            #expect(entity.properties.count == count - 1)
        }
        #expect(withoutTarget != FrozenSchemaFingerprints.v1["SetLog"])

        // A performed exercise loses the link to its sets (a relationship of the history).
        let withoutSets = try fingerprint(of: "SessionExercise", inCopyOf: model) { entity in
            let count = entity.properties.count
            #expect(entity.relationshipsByName["setLogs"] != nil)
            entity.properties = entity.properties.filter { $0.name != "setLogs" }
            #expect(entity.properties.count == count - 1)
        }
        #expect(withoutSets != FrozenSchemaFingerprints.v1["SessionExercise"])

        // The models Core Data builds for version 1 are the ones the stores record: same entities,
        // same hashes, untouched by the copies. So a hash that changes here is a store that no
        // longer matches the frozen one.
        expectFrozenVersionOne(model)
    }

    @Test("Retyping a stored attribute or making it required changes a released model's fingerprint")
    func fingerprintDetectsRetypedAndRequiredAttributes() throws {
        let model = try #require(NSManagedObjectModel.makeManagedObjectModel(for: SchemaV1.models))

        // Control: the whole model copied without a change keeps the frozen fingerprint.
        let control = try fingerprint(of: "SetLog", inCopyOf: model)
        #expect(control == FrozenSchemaFingerprints.v1["SetLog"])

        // The repetitions of a set are stored as decimals instead of whole numbers.
        let retyped = try fingerprint(of: "SetLog", inCopyOf: model) { entity in
            let reps = try #require(entity.attributesByName["reps"])
            #expect(reps.attributeType != NSAttributeType.doubleAttributeType)
            reps.attributeType = .doubleAttributeType
        }
        #expect(retyped != FrozenSchemaFingerprints.v1["SetLog"])

        // A set's load, empty for sets done without weight, becomes required.
        let required = try fingerprint(of: "SetLog", inCopyOf: model) { entity in
            let weight = try #require(entity.attributesByName["weightKg"])
            #expect(weight.isOptional)
            weight.isOptional = false
        }
        #expect(required != FrozenSchemaFingerprints.v1["SetLog"])

        // The copies left the model as it was.
        expectFrozenVersionOne(model)
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

    /// The fingerprint of the entity `name` in a new copy of the whole `model`, after `change`.
    ///
    /// The whole model is copied, never a single entity, so every relationship keeps pointing to
    /// entities of the same model. Each call makes its own copy, which must not share the entity
    /// with `model` and stays alive while the fingerprint is read.
    private func fingerprint(
        of name: String,
        inCopyOf model: NSManagedObjectModel,
        after change: (NSEntityDescription) throws -> Void = { _ in }
    ) throws -> String {
        let copy = try #require(model.copy() as? NSManagedObjectModel)
        let entity = try #require(copy.entitiesByName[name], "No entity \(name) in the copy")
        let sharesEntity = entity === model.entitiesByName[name]
        #expect(!sharesEntity, "The copy shares \(name) with the model")
        try change(entity)
        return withExtendedLifetime(copy) { entity.versionHash.base64EncodedString() }
    }

    /// Expects `model` to have exactly the version 1 entities, each with its frozen fingerprint.
    private func expectFrozenVersionOne(_ model: NSManagedObjectModel) {
        #expect(Set(model.entitiesByName.keys) == Set(FrozenSchemaFingerprints.v1.keys))
        for (name, entity) in model.entitiesByName {
            #expect(entity.versionHash.base64EncodedString() == FrozenSchemaFingerprints.v1[name], "\(name)")
        }
    }
}
