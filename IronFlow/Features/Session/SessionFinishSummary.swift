import Foundation

/// What "Concluir treino?" shows: the sets done out of all of them, the load lifted, what will not be
/// saved and the duration up to the end chosen. Pure logic: it reads the sets it is given and the times
/// of the moment "Concluir" was tapped, never the store.
struct SessionFinishSummary: Identifiable {
    /// A new one each time the sheet opens.
    let id = UUID()
    let doneSets: Int
    let totalSets: Int
    /// The load lifted by the working and failure sets done (`SessionProgress.volumeKg`).
    let volumeKg: Double
    let startedAt: Date
    /// When "Concluir" was tapped: the end with "Usar agora".
    let now: Date
    /// The end offered for a session left open (`SessionService.suggestedEnd`); `nil` otherwise.
    let suggestedEnd: Date?

    /// `sets` holds every set of the session.
    init(sets: [SetLog], startedAt: Date, now: Date, suggestedEnd: Date?) {
        doneSets = sets.filter(\.isCompleted).count
        totalSets = sets.count
        volumeKg = SessionProgress.volumeKg(of: sets)
        self.startedAt = startedAt
        self.now = now
        self.suggestedEnd = suggestedEnd
    }

    /// The sets not done, which are not saved.
    var notDoneSets: Int {
        totalSets - doneSets
    }

    /// How long the session lasts when it ends at `end`: up to its last set done (when that end is
    /// offered) or up to now, `moment` while the sheet stays open (by default, when it opened).
    func duration(endingAt end: SessionEnd, at moment: Date? = nil) -> TimeInterval {
        let current = max(now, moment ?? now)
        let endDate = end == .lastCompletedSet ? (suggestedEnd ?? current) : current
        return max(0, endDate.timeIntervalSince(startedAt))
    }

    /// The sets box: "3/15".
    var setsText: String {
        "\(doneSets)/\(totalSets)"
    }

    /// What VoiceOver reads for the sets box: "3 de 15 séries feitas", "1 de 1 série feita".
    var setsAccessibilityText: String {
        totalSets == 1
            ? String(localized: "\(doneSets) de 1 série feita")
            : String(localized: "\(doneSets) de \(totalSets) séries feitas")
    }

    /// The notice once the session is saved: "Treino salvo · 5 séries · 2.640 kg", every set done and the
    /// load of the working and failure sets; without a load lifted, "Treino salvo · 1 série".
    static func savedText(doneSets: Int, volumeKg: Double) -> String {
        let sets = String(localized: "\(doneSets) séries")
        // Rounded like the number shown: less than half a kilogram is no load.
        guard max(0, volumeKg).rounded() >= 1 else { return String(localized: "Treino salvo · \(sets)") }
        return String(localized: "Treino salvo · \(sets) · \(SessionFormatting.kilogramsText(volumeKg)) kg")
    }

    /// "A série não marcada não será salva.", "As 3 séries não marcadas não serão salvas."; `nil` when
    /// every set is done.
    var notDoneText: String? {
        switch notDoneSets {
        case ...0: nil
        case 1: String(localized: "A série não marcada não será salva.")
        default: String(localized: "As \(notDoneSets) séries não marcadas não serão salvas.")
        }
    }
}
