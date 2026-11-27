import Foundation

/// The form of an exercise of the user's own, as in the approved prototype: a new one, one to edit, a
/// copy of one of the user's own ("Duplicar") or the user's version of a library exercise ("Criar minha
/// versão"). What is missing, the name already taken, whether anything changed, and the muscles that
/// follow the group until the person changes them. Pure logic: no UI and no store access.
struct ExerciseForm: Equatable {
    enum Mode: Equatable {
        case new
        case edit
        /// A copy of the exercise named `sourceName`: of one of the user's own, or of the library.
        case copy(sourceName: String, isSourceCustom: Bool)
    }

    /// Something the form still needs before the exercise can be saved, in the order it is written.
    enum Missing: CaseIterable, Equatable {
        case name, group, equipment, primaryMuscle

        var text: String {
            switch self {
            case .name: String(localized: "nome")
            case .group: String(localized: "grupo")
            case .equipment: String(localized: "equipamento")
            case .primaryMuscle: String(localized: "músculo principal")
            }
        }
    }

    /// What the form compares to know whether anything changed: the name without the spaces around it,
    /// and the kind of machine only with the machine.
    private struct Snapshot: Equatable {
        let name: String
        let group: MuscleGroup?
        let equipment: EquipmentChoice?
        let machine: MachineType?
        let primary: [Muscle]
        let secondary: [Muscle]

        init(_ draft: ExerciseDraft) {
            name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
            group = draft.group
            equipment = draft.equipment
            machine = draft.storedMachine
            primary = draft.primary
            secondary = draft.secondary
        }
    }

    /// The groups offered, in the order of the filters: every group but "Outro".
    static let groups: [MuscleGroup] = MuscleGroup.allCases.filter { $0 != .other }

    let mode: Mode
    private(set) var draft: ExerciseDraft
    /// The muscles come from the group until the person changes them; then changing the group keeps them.
    private(set) var musclesFollowGroup: Bool
    private let start: Snapshot

    /// A new exercise, with the name typed in the search (cut to the longest name, as the field cuts what is
    /// typed) and the group and equipment of the filters on.
    init(name: String = "", group: MuscleGroup? = nil, equipment: Equipment? = nil) {
        let name = String(name.prefix(Validation.maxNameLength))
        let draft = ExerciseDraft(name: name, group: group, equipment: equipment.map(EquipmentChoice.equipment))
        self.init(mode: .new, draft: draft, musclesFollowGroup: true)
    }

    /// The exercise of the user's own to edit. One without muscles of its own gets those of its group,
    /// still following the group.
    init(editing exercise: Exercise) {
        self.init(mode: .edit, draft: ExerciseDraft(exercise), musclesFollowGroup: DefaultExerciseMuscles.showsGroupMuscles(of: exercise))
    }

    /// A copy of `exercise` named `name`: its group, equipment, kind of machine and muscles (from the
    /// library, for a library exercise).
    init(copying exercise: Exercise, name: String) {
        var draft = ExerciseDraft(exercise)
        draft.name = name
        self.init(
            mode: .copy(sourceName: exercise.name, isSourceCustom: exercise.isCustom),
            draft: draft,
            musclesFollowGroup: DefaultExerciseMuscles.showsGroupMuscles(of: exercise)
        )
    }

    private init(mode: Mode, draft: ExerciseDraft, musclesFollowGroup: Bool) {
        var draft = draft
        // "Outro" is not offered as a group: an exercise stored with it chooses one again.
        draft.group = draft.group.flatMap(Self.offered)
        if musclesFollowGroup {
            draft.primary = draft.group.map(DefaultExerciseMuscles.muscles(of:)) ?? []
            draft.secondary = []
        }
        self.mode = mode
        self.draft = draft
        self.musclesFollowGroup = musclesFollowGroup
        self.start = Snapshot(draft)
    }

    private static func offered(_ group: MuscleGroup) -> MuscleGroup? {
        groups.contains(group) ? group : nil
    }

    // MARK: - Changes

    mutating func setName(_ name: String) {
        draft.name = name
    }

    /// Chooses the group; while the muscles follow the group, they become the group's.
    mutating func selectGroup(_ group: MuscleGroup) {
        draft.group = group
        if musclesFollowGroup {
            draft.primary = DefaultExerciseMuscles.muscles(of: group)
            draft.secondary = []
        }
    }

    mutating func selectEquipment(_ equipment: EquipmentChoice) {
        draft.equipment = equipment
    }

    /// Chooses the kind of machine; `nil` is "Não sei".
    mutating func selectMachine(_ machine: MachineType?) {
        draft.machine = machine
    }

    /// Adds the muscle to the main (or secondary) muscles, or takes it out, in the order of the body. A
    /// muscle of the other list cannot be chosen. From then on, the muscles no longer follow the group.
    mutating func toggle(_ muscle: Muscle, primary: Bool) {
        let other = primary ? draft.secondary : draft.primary
        guard !other.contains(muscle) else { return }
        var list = primary ? draft.primary : draft.secondary
        if let index = list.firstIndex(of: muscle) {
            list.remove(at: index)
        } else {
            list.append(muscle)
        }
        list.sort { (Muscle.bodyOrder.firstIndex(of: $0) ?? 0) < (Muscle.bodyOrder.firstIndex(of: $1) ?? 0) }
        if primary {
            draft.primary = list
        } else {
            draft.secondary = list
        }
        musclesFollowGroup = false
    }

    // MARK: - State

    /// Whether anything differs from when the form opened.
    var hasChanges: Bool {
        Snapshot(draft) != start
    }

    /// What is still missing, in order: the main muscle only once a group other than "Corpo inteiro" is chosen.
    var missing: [Missing] {
        var missing: [Missing] = []
        if draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { missing.append(.name) }
        if draft.group == nil { missing.append(.group) }
        if draft.equipment == nil { missing.append(.equipment) }
        if draft.group != nil && draft.needsPrimaryMuscle && draft.primary.isEmpty { missing.append(.primaryMuscle) }
        return missing
    }

    /// "Falta: nome, grupo e equipamento."; `nil` when nothing is missing.
    var missingText: String? {
        guard !missing.isEmpty else { return nil }
        return String(localized: "Falta: \(Self.list(missing.map(\.text))).")
    }

    /// The message below the name when another exercise has it (`ExerciseService.takenNames`, without the
    /// exercise edited).
    func nameMessage(taken: [String: ExerciseNameOwner]) -> String? {
        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, let owner = taken[Validation.comparisonKey(forName: name)] else { return nil }
        if owner.isArchived {
            return String(localized: "Você já tem “\(owner.name)” arquivado. Restaure em Exercícios › Meus ou use outro nome.")
        }
        return String(localized: "Já existe um exercício com esse nome.")
    }

    /// Whether the main button acts: nothing missing, the name free and, when editing, something changed.
    func canSave(taken: [String: ExerciseNameOwner]) -> Bool {
        missing.isEmpty && nameMessage(taken: taken) == nil && (mode != .edit || hasChanges)
    }

    /// Whether "Preenchido pelo grupo. Toque para mudar." shows below the muscles.
    var showsGroupHint: Bool {
        musclesFollowGroup && !draft.primary.isEmpty
    }

    /// The main muscles as the form writes them: their names, or what is expected.
    var primaryText: (text: String, isPlaceholder: Bool) {
        if !draft.primary.isEmpty { return (Self.names(draft.primary), false) }
        guard let group = draft.group else { return (String(localized: "Nenhum ainda"), true) }
        if group == .fullBody { return (String(localized: "Corpo inteiro"), false) }
        return (String(localized: "Escolha pelo menos 1"), true)
    }

    /// The secondary muscles as the form writes them, or that they are optional.
    var secondaryText: (text: String, isPlaceholder: Bool) {
        draft.secondary.isEmpty ? (String(localized: "Nenhum (opcional)"), true) : (Self.names(draft.secondary), false)
    }

    // MARK: - Texts

    var title: String {
        switch mode {
        case .new: String(localized: "Novo exercício")
        case .edit: String(localized: "Editar exercício")
        case .copy(_, let isSourceCustom): isSourceCustom ? String(localized: "Duplicar exercício") : String(localized: "Minha versão")
        }
    }

    var buttonTitle: String {
        switch mode {
        case .new: String(localized: "Criar exercício")
        case .edit: String(localized: "Salvar")
        case .copy(_, let isSourceCustom): isSourceCustom ? String(localized: "Criar cópia") : String(localized: "Criar minha versão")
        }
    }

    /// The note at the top of a copy: what it copies and that it starts without history.
    var copyNote: (title: String, text: String)? {
        guard case .copy(let sourceName, let isSourceCustom) = mode else { return nil }
        if isSourceCustom {
            return (
                String(localized: "Cópia de \(sourceName)"),
                String(localized: "Começa sem histórico, com evolução e recordes próprios. O original continua igual.")
            )
        }
        return (
            String(localized: "Sua versão de \(sourceName)"),
            String(localized: "Começa sem histórico, com evolução e recordes próprios. O exercício da lista continua igual.")
        )
    }

    /// The question before leaving with changes.
    var discardQuestion: (title: String, message: String) {
        mode == .edit
            ? (String(localized: "Descartar alterações?"), String(localized: "As mudanças não serão salvas."))
            : (String(localized: "Descartar exercício?"), String(localized: "O exercício não será criado."))
    }

    /// "a", "a e b", "a, b e c".
    static func list(_ items: [String]) -> String {
        guard items.count > 1, let last = items.last else { return items.first ?? "" }
        return String(localized: "\(items.dropLast().joined(separator: ", ")) e \(last)")
    }

    private static func names(_ muscles: [Muscle]) -> String {
        muscles.map { String(localized: $0.displayName) }.joined(separator: ", ")
    }
}
