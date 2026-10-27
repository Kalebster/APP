import Foundation
import SwiftData

typealias BodyWeightEntry = SchemaV2.BodyWeightEntry

extension SchemaV2 {
    /// One body weight measurement. A day has one: a new day's weight is a new entry, so the history is
    /// kept, and a weight saved again the same day updates that day's entry (`ProfileService`).
    @Model
    final class BodyWeightEntry {
        @Attribute(.unique) var id: UUID = UUID()
        var createdAt: Date = Date.now
        var updatedAt: Date = Date.now
        /// When the weight was measured.
        var measuredAt: Date = Date.now
        var weightKg: Double = 0

        init(weightKg: Double, measuredAt: Date) {
            let now = Date.now
            self.createdAt = now
            self.updatedAt = now
            self.measuredAt = measuredAt
            self.weightKg = weightKg
        }
    }
}
