#if DEBUG
import Foundation

/// The history of the approved prototype, for the screenshots of the exercise screen: the same sessions
/// ("Push", "Pull" and "Pernas", from 24 April to 15 October 2026) and the same sets of its 15 exercises,
/// made by the same steps and the same pseudo-random sequences as the prototype's script (`H_S` and
/// `EX_PROF`), so the screen shows the prototype's numbers. A test hook: Debug builds only.
enum UITestPrototypeHistory {
    struct SetValues: Equatable {
        let type: SetType
        let weightKg: Double
        let reps: Int
    }

    struct PerformedExercise: Equatable {
        let name: String
        let sets: [SetValues]
    }

    struct Session: Equatable {
        let name: String
        /// The day, as year, month and day.
        let day: DateComponents
        let durationMinutes: Int
        var exercises: [PerformedExercise]
    }

    /// How an exercise of the prototype progresses (`EX_PROF`): the workout it is in, the load from `start`
    /// to `end` in steps of `step`, the range of repetitions, the working sets and the extra sets.
    private struct Profile {
        let name: String
        let workout: String
        var start: Double = 0
        var end: Double = 0
        var step: Double = 1
        var reps: ClosedRange<Int> = 1...1
        let workingSets: Int
        var warmup: (Double, Int)?
        var feeder: (Double, Int)?
        /// The failure set: this much lighter than the working load.
        var failure: Double?
        /// The working sets after the first are one step lighter.
        var drop = false
        /// Only in the most recent sessions of its workout.
        var lastSessions: Int?
        /// Body weight: the repetitions of the top set from the first to the last session.
        var bodyweight: ClosedRange<Int>?
    }

    /// The prototype's sequence: seed × 9301 + 49297, modulo 233280.
    private struct RandomSequence {
        var seed: Int

        mutating func next() -> Double {
            seed = (seed * 9_301 + 49_297) % 233_280
            return Double(seed) / 233_280
        }
    }

    private static let profiles: [Profile] = [
        Profile(name: "Supino Reto (Barra)", workout: "Push", start: 50, end: 62, step: 2, reps: 8...10, workingSets: 2, warmup: (40, 15), feeder: (50, 6), failure: -7, drop: true),
        Profile(name: "Supino Inclinado (Halter)", workout: "Push", start: 16, end: 22, step: 2, reps: 8...12, workingSets: 3),
        Profile(name: "Desenvolvimento (Halter)", workout: "Push", start: 14, end: 18, step: 2, reps: 8...12, workingSets: 3, warmup: (10, 15)),
        Profile(name: "Elevação Lateral (Halter)", workout: "Push", start: 10, end: 10, step: 2, reps: 12...12, workingSets: 3, lastSessions: 1),
        Profile(name: "Tríceps Corda (Polia)", workout: "Push", start: 17.5, end: 25, step: 2.5, reps: 10...15, workingSets: 2, failure: -5),
        Profile(name: "Flexão", workout: "Push", workingSets: 3, bodyweight: 12...24),
        Profile(name: "Puxada Alta Aberta (Polia)", workout: "Pull", start: 55, end: 70, step: 5, reps: 8...10, workingSets: 3),
        Profile(name: "Barra Fixa (Graviton)", workout: "Pull", start: 45, end: 25, step: 5, reps: 6...8, workingSets: 3),
        Profile(name: "Remada Curvada (Barra)", workout: "Pull", start: 40, end: 50, step: 2, reps: 8...10, workingSets: 3),
        Profile(name: "Rosca Direta (Barra)", workout: "Pull", start: 24, end: 30, step: 2, reps: 8...12, workingSets: 2, failure: -5),
        Profile(name: "Agachamento Livre (Barra)", workout: "Pernas", start: 80, end: 100, step: 5, reps: 6...8, workingSets: 3, warmup: (40, 10)),
        Profile(name: "Leg Press 45° (Máquina)", workout: "Pernas", start: 140, end: 180, step: 10, reps: 10...15, workingSets: 3),
        Profile(name: "Cadeira Extensora (Máquina)", workout: "Pernas", start: 35, end: 45, step: 5, reps: 10...15, workingSets: 2, failure: -5),
        Profile(name: "Mesa Flexora (Máquina)", workout: "Pernas", start: 30, end: 40, step: 5, reps: 10...15, workingSets: 3),
        Profile(name: "Stiff (Barra)", workout: "Pernas", start: 40, end: 50, step: 2, reps: 8...12, workingSets: 3),
    ]

    /// JavaScript's `Math.round`: halves go up.
    private static func jsRound(_ value: Double) -> Double {
        (value + 0.5).rounded(.down)
    }

    /// The sessions, the most recent first, as the prototype's `H_S`, each with its exercises in the
    /// prototype's order.
    static func sessions() -> [Session] {
        var sessions = [
            Session(name: "Pernas", day: DateComponents(year: 2026, month: 10, day: 15), durationMinutes: 55, exercises: []),
            Session(name: "Pull", day: DateComponents(year: 2026, month: 10, day: 12), durationMinutes: 48, exercises: []),
            Session(name: "Push", day: DateComponents(year: 2026, month: 10, day: 9), durationMinutes: 62, exercises: []),
        ]
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        let names = ["Pernas", "Pull", "Push"]
        var sequence = RandomSequence(seed: 11)
        guard let limit = calendar.date(from: DateComponents(year: 2026, month: 4, day: 22)),
              var day = calendar.date(from: DateComponents(year: 2026, month: 10, day: 7)) else { return [] }
        var index = 0
        while day > limit {
            let name = names[index % 3]
            let duration = 44 + Int(jsRound(sequence.next() * 22))
            // The volume, the record and the counts of the prototype's list: drawn to keep the sequence.
            _ = sequence.next()
            _ = sequence.next()
            _ = sequence.next()
            _ = sequence.next()
            sessions.append(Session(name: name, day: calendar.dateComponents([.year, .month, .day], from: day), durationMinutes: duration, exercises: []))
            index += 1
            let gap = 2 + (sequence.next() < 0.4 ? 1 : 0)
            guard let next = calendar.date(byAdding: .day, value: -gap, to: day) else { break }
            day = next
        }

        var exercisesSequence = RandomSequence(seed: 7)
        for profile in profiles {
            var positions = sessions.indices.filter { sessions[$0].name == profile.workout }
            if let last = profile.lastSessions {
                positions = Array(positions.prefix(last))
            }
            positions.reverse()
            let count = positions.count
            for (order, position) in positions.enumerated() {
                let progress = count > 1 ? Double(order) / Double(count - 1) : 1
                let sets = sets(of: profile, progress: progress, isLast: order == count - 1, order: order, sequence: &exercisesSequence)
                sessions[position].exercises.append(PerformedExercise(name: profile.name, sets: sets))
            }
        }
        return sessions
    }

    private static func sets(of profile: Profile, progress: Double, isLast: Bool, order: Int, sequence: inout RandomSequence) -> [SetValues] {
        var sets: [SetValues] = []
        if let bodyweight = profile.bodyweight {
            let top = isLast
                ? bodyweight.upperBound
                : Int(jsRound(Double(bodyweight.lowerBound) + Double(bodyweight.upperBound - bodyweight.lowerBound) * progress - sequence.next() * 2))
            for set in 0..<profile.workingSets {
                let less = set > 0 && sequence.next() < 0.5 ? 1 : 0
                sets.append(SetValues(type: .working, weightKg: 0, reps: max(bodyweight.lowerBound - 2, top - set * 2 - less)))
            }
            return sets
        }
        var load = jsRound((profile.start + (profile.end - profile.start) * pow(progress, 0.85)) / profile.step) * profile.step
        if !isLast, order > 1, sequence.next() < (profile.end >= profile.start ? 0.14 : 0.07) {
            load += profile.end >= profile.start ? -profile.step : profile.step
        }
        if isLast {
            load = profile.end
        }
        let reps = isLast
            ? profile.reps.upperBound
            : profile.reps.lowerBound + Int((sequence.next() * Double(profile.reps.upperBound - profile.reps.lowerBound + 1)).rounded(.down))
        if let warmup = profile.warmup {
            sets.append(SetValues(type: .warmup, weightKg: warmup.0, reps: warmup.1))
        }
        if let feeder = profile.feeder {
            sets.append(SetValues(type: .feeder, weightKg: feeder.0, reps: feeder.1))
        }
        for set in 0..<profile.workingSets {
            let weight = jsRound((load - (profile.drop && set > 0 ? profile.step : 0)) * 100) / 100
            sets.append(SetValues(type: .working, weightKg: weight, reps: max(profile.reps.lowerBound - 1, reps - set)))
        }
        if let failure = profile.failure {
            sets.append(SetValues(type: .failure, weightKg: load + failure, reps: reps + 2))
        }
        return sets
    }
}
#endif
