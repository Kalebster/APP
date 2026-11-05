import Testing
@testable import IronFlow

/// How long a short notice stays on screen: 2,5 s, or 4 s when its text has more than 40 characters.
@MainActor
struct ToastMessageTests {
    @Test("Up to 40 characters, 2,5 s; more than 40, 4 s")
    func duration() {
        #expect(ToastMessage("Série removida").duration == .seconds(2.5))
        #expect(ToastMessage("Treino salvo · 5 séries · 2.640 kg").duration == .seconds(2.5))
        let forty = String(repeating: "a", count: 40)
        #expect(ToastMessage(forty).duration == .seconds(2.5))
        #expect(ToastMessage(forty + "b").duration == .seconds(4))
        // Accented letters count once each, as on screen.
        #expect(ToastMessage("Todas as séries feitas. Toque em Concluir.").duration == .seconds(4))
        #expect(ToastMessage("Exercício removido do treino").duration == .seconds(2.5))
    }
}
