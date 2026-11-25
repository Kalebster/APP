import Foundation
import Testing
@testable import IronFlow

/// The form of an exercise of the user's own: what is missing, the names taken, the muscles that follow
/// the group, and the texts of each mode.
@MainActor
struct ExerciseFormTests {
    private let noNames: [String: ExerciseNameOwner] = [:]

    @Test("A new form lists what is missing in order; the main muscle only once a group other than Corpo inteiro is chosen")
    func missing() {
        var form = ExerciseForm()
        #expect(form.missing == [.name, .group, .equipment])
        #expect(form.missingText == "Falta: nome, grupo e equipamento.")
        #expect(form.canSave(taken: noNames) == false)

        form.setName("  Remada Cavalinho ")
        form.selectGroup(.upperBack)
        #expect(form.missingText == "Falta: equipamento.")
        form.selectEquipment(.other)
        #expect(form.missing.isEmpty)
        #expect(form.missingText == nil)
        #expect(form.canSave(taken: noNames))

        // Without main muscles, the main muscle is missing; with Corpo inteiro, it is not.
        form.toggle(.upperBack, primary: true)
        #expect(form.missing == [.primaryMuscle])
        #expect(form.missingText == "Falta: músculo principal.")
        form.selectGroup(.fullBody)
        #expect(form.missing.isEmpty)
        #expect(form.primaryText.text == "Corpo inteiro")
    }

    @Test("The muscles follow the group until the person changes them; then changing the group keeps them")
    func musclesFollowTheGroup() {
        var form = ExerciseForm()
        #expect(form.primaryText.text == "Nenhum ainda")
        #expect(form.primaryText.isPlaceholder == true)
        #expect(form.secondaryText.text == "Nenhum (opcional)")
        #expect(form.secondaryText.isPlaceholder == true)
        form.selectGroup(.shoulders)
        #expect(form.draft.primary == [.frontDelts, .sideDelts, .rearDelts])
        #expect(form.showsGroupHint)
        form.selectGroup(.back)
        #expect(form.draft.primary == [.lats])

        form.toggle(.biceps, primary: false)
        #expect(form.musclesFollowGroup == false)
        #expect(form.showsGroupHint == false)
        form.selectGroup(.chest)
        #expect(form.draft.primary == [.lats])
        #expect(form.draft.secondary == [.biceps])
        #expect(form.primaryText.text == "Dorsais")
        #expect(form.primaryText.isPlaceholder == false)
    }

    @Test("A muscle of the other list cannot be chosen, and the lists keep the order of the body")
    func blockedAndOrdered() {
        var form = ExerciseForm(name: "Remada", group: .upperBack, equipment: .machine)
        form.toggle(.lats, primary: false)
        form.toggle(.traps, primary: false)
        form.toggle(.biceps, primary: false)
        #expect(form.draft.secondary == [.traps, .lats, .biceps])
        form.toggle(.lats, primary: true)
        #expect(form.draft.primary == [.upperBack])
        form.toggle(.traps, primary: false)
        #expect(form.draft.secondary == [.lats, .biceps])
        #expect(form.secondaryText.text == "Dorsais, Bíceps")
    }

    @Test("A new form starts with the search and the filters on, and asks before discarding only after a change")
    func newFromFilters() {
        var form = ExerciseForm(name: "Leg Press", group: .quadriceps, equipment: .machine)
        #expect(form.draft.name == "Leg Press")
        #expect(form.draft.group == .quadriceps)
        #expect(form.draft.equipment == .equipment(.machine))
        #expect(form.draft.primary == [.quadriceps])
        #expect(form.hasChanges == false)
        #expect(form.title == "Novo exercício")
        #expect(form.buttonTitle == "Criar exercício")
        #expect(form.discardQuestion.title == "Descartar exercício?")
        #expect(form.discardQuestion.message == "O exercício não será criado.")

        form.setName("Leg Press ")
        #expect(form.hasChanges == false)
        form.selectMachine(.track)
        #expect(form.hasChanges)

        // "Outro" is not a group of the form.
        #expect(ExerciseForm(group: .other).draft.group == nil)
        #expect(ExerciseForm.groups.contains(.other) == false)
        #expect(ExerciseForm.groups.count == 16)
    }

    @Test("The kind of machine only counts with the machine")
    func machineOnlyWithTheMachine() {
        var form = ExerciseForm(name: "Puxada", group: .back, equipment: .machine)
        form.selectMachine(.graviton)
        #expect(form.draft.storedMachine == .graviton)
        form.selectEquipment(.equipment(.cable))
        #expect(form.draft.storedMachine == nil)
        #expect(form.hasChanges)
    }

    @Test("Names taken by an active exercise or an archived one of the user's own have their own messages")
    func nameMessages() {
        let taken: [String: ExerciseNameOwner] = [
            Validation.comparisonKey(forName: "Supino Reto (Barra)"): ExerciseNameOwner(name: "Supino Reto (Barra)", isArchived: false),
            Validation.comparisonKey(forName: "Remada Cavalinho"): ExerciseNameOwner(name: "Remada Cavalinho", isArchived: true),
        ]
        var form = ExerciseForm(name: "", group: .chest, equipment: .barbell)
        form.setName("supino reto (BARRA)")
        #expect(form.nameMessage(taken: taken) == "Já existe um exercício com esse nome.")
        #expect(form.canSave(taken: taken) == false)
        form.setName(" remada cavalinho ")
        #expect(form.nameMessage(taken: taken) == "Você já tem “Remada Cavalinho” arquivado. Restaure em Exercícios › Meus ou use outro nome.")
        form.setName("Remada Nova")
        #expect(form.nameMessage(taken: taken) == nil)
        #expect(form.canSave(taken: taken))
    }

    @Test("Editing saves only after a change; one without muscles of its own gets those of its group")
    func edit() {
        let exercise = Exercise(name: "Meu Supino", muscleGroup: .chest, isCustom: true)
        var form = ExerciseForm(editing: exercise)
        #expect(form.title == "Editar exercício")
        #expect(form.buttonTitle == "Salvar")
        #expect(form.draft.equipment == .other)
        #expect(form.draft.primary == [.chest])
        #expect(form.musclesFollowGroup)
        #expect(form.canSave(taken: noNames) == false)
        #expect(form.discardQuestion.title == "Descartar alterações?")
        #expect(form.discardQuestion.message == "As mudanças não serão salvas.")
        form.selectEquipment(.equipment(.dumbbell))
        #expect(form.canSave(taken: noNames))

        let chosen = Exercise(name: "Puxada", muscleGroup: .back, isCustom: true)
        chosen.equipment = .machine
        chosen.machineType = .lever
        chosen.primaryMuscles = [.lats]
        chosen.secondaryMuscles = [.biceps]
        let edit = ExerciseForm(editing: chosen)
        #expect(edit.musclesFollowGroup == false)
        #expect(edit.draft.machine == .lever)
        #expect(edit.draft.secondary == [.biceps])
    }

    @Test("A copy of a library exercise is the user's version; a copy of one of the user's own is a copy")
    func copies() {
        let library = Exercise(name: "Leg Press 45° (Máquina)", muscleGroup: .quadriceps, isCustom: false, libraryKey: "leg-press")
        let version = ExerciseForm(copying: library, name: "Leg Press 45° (Máquina) 2")
        #expect(version.title == "Minha versão")
        #expect(version.buttonTitle == "Criar minha versão")
        #expect(version.copyNote?.title == "Sua versão de Leg Press 45° (Máquina)")
        #expect(version.copyNote?.text == "Começa sem histórico, com evolução e recordes próprios. O exercício da lista continua igual.")
        #expect(version.draft.machine == .track)
        #expect(version.draft.primary == [.quadriceps, .glutes])
        #expect(version.draft.secondary == [.adductors, .hamstrings])
        #expect(version.musclesFollowGroup == false)
        #expect(version.canSave(taken: noNames))

        let own = Exercise(name: "Puxada", muscleGroup: .back, isCustom: true)
        let copy = ExerciseForm(copying: own, name: "Puxada 2")
        #expect(copy.title == "Duplicar exercício")
        #expect(copy.buttonTitle == "Criar cópia")
        #expect(copy.copyNote?.title == "Cópia de Puxada")
        #expect(copy.copyNote?.text == "Começa sem histórico, com evolução e recordes próprios. O original continua igual.")
        #expect(copy.draft.primary == [.lats])
        #expect(copy.musclesFollowGroup)
        #expect(ExerciseForm().copyNote == nil)
    }

    @Test("Lists read as in Portuguese")
    func lists() {
        #expect(ExerciseForm.list(["Push"]) == "Push")
        #expect(ExerciseForm.list(["Push", "Pull"]) == "Push e Pull")
        #expect(ExerciseForm.list(["Push", "Pull", "Pernas"]) == "Push, Pull e Pernas")
        #expect(ExerciseForm.list([]) == "")
    }
}
