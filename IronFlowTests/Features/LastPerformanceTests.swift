import Testing
@testable import IronFlow

/// How the sets done the last time are paired with the sets of now: by type, and by the order within
/// the type.
struct LastPerformanceTests {
    private let warmup = PreviousSet(weightKg: 20, reps: 15, setType: .warmup)
    private let feeder = PreviousSet(weightKg: 40, reps: 5, setType: .feeder)
    private let first = PreviousSet(weightKg: 60, reps: 10, setType: .working)
    private let second = PreviousSet(weightKg: 60, reps: 9, setType: .working)
    private let third = PreviousSet(weightKg: 57.5, reps: 8, setType: .working)
    private let failure = PreviousSet(weightKg: 50, reps: 12, setType: .failure)

    @Test("A warm-up not done the last time gets nothing, and the other sets keep their own")
    func skippedWarmup() {
        #expect(LastPerformance.matched([feeder, first, second], to: [.warmup, .feeder, .working, .working])
            == [nil, feeder, first, second])
    }

    @Test("With a set removed, the sets of its type take the ones done in their order; a set added gets nothing")
    func removedAndAddedSets() {
        #expect(LastPerformance.matched([first, second, third], to: [.working, .working]) == [first, second])
        #expect(LastPerformance.matched([first, second], to: [.working, .working, .working]) == [first, second, nil])
        // A working set not done the last time: the next one done takes its place.
        #expect(LastPerformance.matched([first, third], to: [.working, .working, .working]) == [first, third, nil])
    }

    @Test("Sets whose types changed get the sets of their new type")
    func changedTypes() {
        #expect(LastPerformance.matched([warmup, first, failure], to: [.working, .warmup, .failure])
            == [first, warmup, failure])
        #expect(LastPerformance.matched([warmup, first], to: [.failure, .feeder]) == [nil, nil])
    }

    @Test("Sets recorded before set types existed are working sets: a warm-up planned now gets none of them")
    func historyBeforeSetTypes() {
        let old = [PreviousSet(weightKg: 60, reps: 10), PreviousSet(weightKg: 60, reps: 9)]
        #expect(old.allSatisfy { $0.setType == .working })
        #expect(LastPerformance.matched(old, to: [.warmup, .working, .working]) == [nil, old[0], old[1]])
        #expect(LastPerformance.matched(old, to: [.working, .working]) == old)
    }

    @Test("Without a last time, no set gets anything")
    func noLastTime() {
        #expect(LastPerformance.matched([], to: [.warmup, .working]) == [nil, nil])
        #expect(LastPerformance.matched([first], to: []).isEmpty)
    }
}
