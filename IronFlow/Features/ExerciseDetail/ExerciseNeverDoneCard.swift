import SwiftUI

/// In place of the evolution and the history of an exercise never done in a finished session.
struct ExerciseNeverDoneCard: View {
    var body: some View {
        VStack(spacing: 8) {
            IconTile(.chart, iconSize: 18, side: 36, cornerRadius: 10)
            Text("Você ainda não fez este exercício")
                .scaledFont(15, weight: .bold)
                .foregroundStyle(Theme.Colors.brightText)
            Text("Quando concluir um treino com ele, a última vez, a melhor série, a evolução e o histórico aparecem aqui.")
                .scaledFont(13, lineHeight: 1.4)
                .foregroundStyle(Theme.Colors.secondaryText)
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity)
        .cardStyle(padding: EdgeInsets(top: 18, leading: 16, bottom: 18, trailing: 16), cornerRadius: 17)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("exercise.neverDone")
    }
}
