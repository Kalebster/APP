import Foundation

/// The second list approved by the owner for the library: 200 new exercises, as it was written. Each block
/// is a muscle group (its storage key in parentheses) and each line "Nome · equipamento · foco" is a new
/// exercise. The library has them, in this order, after the exercises of the first list in each group.
enum ApprovedExerciseList2 {
    static let text = """
Peito (chest):
  Supino Reto Unilateral (Halter) · dumbbell · Peitoral médio e core
  Supino Reto Pegada Neutra (Halter) · dumbbell · Peitoral e tríceps
  Supino Reto Pegada Aberta (Barra) · barbell · Peitoral médio
  Supino Reto Unilateral (Máquina) · machine · Peitoral médio
  Supino Reto Unilateral (Polia) · cable · Peitoral médio
  Supino Inclinado Unilateral (Halter) · dumbbell · Peitoral superior
  Supino Inclinado Pegada Neutra (Halter) · dumbbell · Peitoral superior e tríceps
  Supino Inclinado Iso-Lateral (Máquina) · machine · Peitoral superior
  Supino Inclinado Unilateral (Máquina) · machine · Peitoral superior
  Supino Inclinado Unilateral (Polia) · cable · Peitoral superior
  Supino Declinado Iso-Lateral (Máquina) · machine · Peitoral inferior
  Supino Squeeze (Halter) · dumbbell · Peitoral (contração)
  Supino Guilhotina (Barra) · barbell · Peitoral superior
  Supino no Chão (Barra) · barbell · Peitoral e tríceps
  Supino no Chão (Halter) · dumbbell · Peitoral e tríceps
  Supino Landmine (Barra) · barbell · Peitoral superior
  Crucifixo Declinado (Halter) · dumbbell · Peitoral inferior
  Crucifixo (Elástico) · band · Peitoral médio
  Svend Press (Anilha) · plate · Peitoral (contração)
  Peito na Paralela (Graviton) · machine · Peitoral inferior
  Flexão Aberta · bodyweight · Peitoral médio
  Flexão (Anilha) · plate · Peitoral e tríceps
  Flexão (Elástico) · band · Peitoral e tríceps
  Flexão Arqueiro · bodyweight · Peitoral (um lado por vez)
  Flexão Explosiva · bodyweight · Peitoral (potência)
Dorsais (back):
  Barra Fixa (Pegada Neutra) · bodyweight · Dorsal e bíceps
  Barra Fixa com Peso (Anilha) · plate · Dorsal (largura)
  Barra Fixa Supinada com Peso (Anilha) · plate · Dorsal e bíceps
  Barra Fixa (Elástico) · band · Dorsal (largura)
  Barra Fixa Supinada (Graviton) · machine · Dorsal e bíceps
  Puxada Alta Pegada Neutra (Polia) · cable · Dorsal (parte baixa)
  Puxada Atrás da Nuca (Polia) · cable · Dorsal (largura)
  Puxada Alta Supinada (Máquina) · machine · Dorsal e bíceps
  Puxada Alta Fechada (Máquina) · machine · Dorsal (parte baixa)
  Puxada Alta (Elástico) · band · Dorsal (largura)
  Pullover Corda (Polia) · cable · Dorsal (isolado)
  Pullover Unilateral (Polia) · cable · Dorsal (isolado)
  Remada Kroc (Halter) · dumbbell · Dorsal
  Remada Meadows (Barra) · barbell · Dorsal
  Remada Alta Articulada Unilateral (Máquina) · machine · Dorsal
  Remada Baixa Supinada (Polia) · cable · Dorsal (parte baixa)
  Remada Curvada Supinada (Halter) · dumbbell · Dorsal (parte baixa)
  Remada Curvada Supinada (Smith) · smith · Dorsal (parte baixa)
Costas superiores (upperBack):
  Remada Pendlay (Barra) · barbell · Espessura das costas
  Remada Invertida · bodyweight · Meio das costas
  Remada Apoiada no Banco (Barra) · barbell · Meio das costas
  Remada Apoiada (Máquina) · machine · Meio das costas
  Remada Unilateral (Smith) · smith · Meio das costas
  Remada Curvada (Elástico) · band · Meio das costas
  Remada Sentada (Elástico) · band · Meio das costas
  Remada Gorila (Kettlebell) · kettlebell · Meio das costas
  Remada Renegada (Halter) · dumbbell · Costas e core
  Retração Escapular na Barra Fixa · bodyweight · Escápulas e trapézio inferior
Trapézio (traps):
  Encolhimento Atrás do Corpo (Barra) · barbell · Trapézio superior
  Encolhimento Inclinado (Halter) · dumbbell · Trapézio médio
  Elevação Y (Halter) · dumbbell · Trapézio inferior
  Elevação Y (Polia) · cable · Trapézio inferior
Lombar (lowerBack):
  Levantamento Terra (Barra Hexagonal) · barbell · Lombar e cadeia posterior
  Levantamento Terra Déficit (Barra) · barbell · Lombar e cadeia posterior
  Rack Pull (Barra) · barbell · Lombar e trapézio
  Levantamento Terra (Kettlebell) · kettlebell · Lombar e cadeia posterior
  Bird Dog · bodyweight · Lombar (estabilidade)
Ombros (shoulders):
  Desenvolvimento Sentado (Barra) · barbell · Deltoide anterior
  Desenvolvimento Atrás da Nuca (Barra) · barbell · Deltoides anterior e lateral
  Desenvolvimento Atrás da Nuca (Smith) · smith · Deltoides anterior e lateral
  Desenvolvimento Unilateral (Halter) · dumbbell · Deltoide anterior e core
  Desenvolvimento Pegada Neutra (Halter) · dumbbell · Deltoide anterior
  Desenvolvimento Iso-Lateral (Máquina) · machine · Deltoide anterior
  Desenvolvimento Unilateral (Máquina) · machine · Deltoide anterior
  Desenvolvimento (Kettlebell) · kettlebell · Deltoide anterior
  Desenvolvimento (Elástico) · band · Deltoide anterior
  Desenvolvimento Landmine (Barra) · barbell · Deltoide anterior
  Push Press (Barra) · barbell · Ombros e pernas (potência)
  Elevação Lateral Sentado (Halter) · dumbbell · Deltoide lateral
  Elevação Lateral (Elástico) · band · Deltoide lateral
  Elevação Frontal Alternada (Halter) · dumbbell · Deltoide anterior
  Elevação Frontal Unilateral (Polia) · cable · Deltoide anterior
  Elevação Frontal (Elástico) · band · Deltoide anterior
  Crucifixo Invertido Inclinado (Halter) · dumbbell · Deltoide posterior
  Crucifixo Invertido (Elástico) · band · Deltoide posterior
  Face Pull (Elástico) · band · Deltoide posterior e manguito rotador
  Remada Alta (Smith) · smith · Deltoide lateral e trapézio
  Rotação Externa (Halter) · dumbbell · Manguito rotador
  Rotação Externa (Elástico) · band · Manguito rotador
  Rotação Interna (Polia) · cable · Manguito rotador
  Flexão Pike · bodyweight · Deltoide anterior
  Flexão em Parada de Mão · bodyweight · Deltoide anterior e tríceps
Bíceps (biceps):
  Rosca Direta (Máquina) · machine · Bíceps (geral)
  Rosca Direta (Elástico) · band · Bíceps (geral)
  Rosca Direta Pegada Fechada (Barra W) · barbell · Bíceps (cabeça longa)
  Rosca 21 (Barra) · barbell · Bíceps (geral)
  Rosca Arrastada (Barra) · barbell · Bíceps (cabeça longa)
  Rosca Martelo Alternada (Halter) · dumbbell · Braquial e braquiorradial
  Rosca Martelo Cruzada (Halter) · dumbbell · Braquial
  Rosca Scott (Barra) · barbell · Bíceps (cabeça curta)
  Rosca Scott Unilateral (Polia) · cable · Bíceps (cabeça curta)
  Rosca Scott Unilateral (Máquina) · machine · Bíceps (cabeça curta)
  Rosca Concentrada (Polia) · cable · Pico do bíceps
  Rosca Zottman (Halter) · dumbbell · Bíceps e antebraço
  Rosca Alta (Polia) · cable · Pico do bíceps
Tríceps (triceps):
  Tríceps Pulley Invertido (Polia) · cable · Cabeça medial
  Tríceps Pulley Barra V (Polia) · cable · Cabeças lateral e medial
  Tríceps Cruzado (Polia) · cable · Cabeça lateral
  Tríceps (Elástico) · band · Cabeça lateral
  Extensão de Tríceps Acima da Cabeça Unilateral (Polia) · cable · Cabeça longa
  Extensão de Tríceps Acima da Cabeça (Máquina) · machine · Cabeça longa
  Extensão de Tríceps Acima da Cabeça (Elástico) · band · Cabeça longa
  Tríceps Testa (Barra) · barbell · Cabeça longa
  Tríceps Testa Inclinado (Barra W) · barbell · Cabeça longa
  Tríceps Testa Unilateral (Halter) · dumbbell · Cabeça longa
  Tate Press (Halter) · dumbbell · Cabeças lateral e medial
  Supino Fechado (Halter) · dumbbell · Tríceps e peitoral
  Tríceps na Paralela com Peso (Anilha) · plate · Tríceps (geral)
  Tríceps na Paralela (Graviton) · machine · Tríceps (geral)
  Tríceps no Banco com Peso (Anilha) · plate · Tríceps (geral)
  Flexão Fechada · bodyweight · Tríceps e peitoral
Antebraços (forearms):
  Rosca de Punho (Polia) · cable · Flexores do antebraço
  Rosca de Punho Atrás do Corpo (Barra) · barbell · Flexores do antebraço
  Rosca Invertida (Barra) · barbell · Braquiorradial
  Rolo de Antebraço (Anilha) · plate · Antebraço (geral)
  Rotação de Punho (Halter) · dumbbell · Pronadores e supinadores
Abdômen (abs):
  Abdominal Completo · bodyweight · Reto abdominal
  Abdominal Declinado (Anilha) · plate · Reto abdominal
  Abdominal Canivete · bodyweight · Reto abdominal
  Abdominal Remador · bodyweight · Reto abdominal
  Abdominal Toque no Calcanhar · bodyweight · Oblíquos
  Abdominal na Bola Suíça · bodyweight · Reto abdominal
  Elevação de Joelhos na Barra Fixa · bodyweight · Reto abdominal (parte inferior)
  Elevação de Pernas na Paralela · bodyweight · Reto abdominal (parte inferior)
  Elevação de Pernas no Banco Declinado · bodyweight · Reto abdominal (parte inferior)
  Pés na Barra · bodyweight · Reto abdominal e flexores do quadril
  Limpador de Para-brisa · bodyweight · Oblíquos
  Escalador · bodyweight · Core e condicionamento
  Flexão Lateral (Halter) · dumbbell · Oblíquos
  Flexão Lateral (Polia) · cable · Oblíquos
  Rotação Russa (Halter) · dumbbell · Oblíquos
  Rotação de Tronco (Máquina) · machine · Oblíquos
  Lenhador Invertido (Polia) · cable · Oblíquos (rotação)
  Pallof Press (Polia) · cable · Core (antirrotação)
Quadríceps (quadriceps):
  Agachamento (Halter) · dumbbell · Quadríceps e glúteos
  Agachamento no Banco (Barra) · barbell · Quadríceps e glúteos
  Agachamento Zercher (Barra) · barbell · Quadríceps e core
  Agachamento Overhead (Barra) · barbell · Quadríceps, ombros e core
  Agachamento Frontal (Smith) · smith · Quadríceps
  Agachamento V-Squat (Máquina) · machine · Quadríceps
  Agachamento com Cinto (Máquina) · machine · Quadríceps e glúteos
  Agachamento Búlgaro (Barra) · barbell · Quadríceps e glúteos
  Agachamento Búlgaro · bodyweight · Quadríceps e glúteos
  Agachamento Pistol · bodyweight · Quadríceps e equilíbrio
  Agachamento Cossaco · bodyweight · Quadríceps e adutores
  Agachamento com Salto · bodyweight · Quadríceps (potência)
  Leg Press Vertical (Máquina) · machine · Quadríceps
  Afundo · bodyweight · Quadríceps e glúteos
  Afundo Reverso (Halter) · dumbbell · Quadríceps e glúteos
  Afundo Reverso (Barra) · barbell · Quadríceps e glúteos
  Afundo Reverso (Smith) · smith · Quadríceps e glúteos
  Afundo Lateral (Halter) · dumbbell · Quadríceps e adutores
  Passada · bodyweight · Quadríceps e glúteos
  Subida no Banco · bodyweight · Quadríceps e glúteos
  Subida no Banco (Barra) · barbell · Quadríceps e glúteos
Posteriores de coxa (hamstrings):
  Mesa Flexora Unilateral (Máquina) · machine · Posteriores (isolado)
  Cadeira Flexora Unilateral (Máquina) · machine · Posteriores (isolado)
  Flexora Ajoelhada (Máquina) · machine · Posteriores (isolado)
  Mesa Flexora (Halter) · dumbbell · Posteriores (isolado)
  Flexora em Pé (Polia) · cable · Posteriores (isolado)
  Flexora na Bola Suíça · bodyweight · Posteriores e glúteos
  Stiff (Kettlebell) · kettlebell · Posteriores e glúteos
  Glute Ham Raise (Máquina) · machine · Posteriores e glúteos
Glúteos (glutes):
  Elevação Pélvica (Halter) · dumbbell · Glúteo máximo
  Elevação Pélvica Unilateral · bodyweight · Glúteo máximo
  Elevação Pélvica Unilateral (Máquina) · machine · Glúteo máximo
  Ponte de Glúteo (Barra) · barbell · Glúteo máximo
  Ponte de Glúteo Unilateral · bodyweight · Glúteo máximo
  Glúteo Quatro Apoios · bodyweight · Glúteo máximo
  Glúteo Coice (Smith) · smith · Glúteo máximo
  Hiperextensão Reversa (Máquina) · machine · Glúteos e lombar
  Pull Through (Polia) · cable · Glúteos e posteriores
  Agachamento Hack Invertido (Máquina) · machine · Glúteos e posteriores
  Agachamento Sumô (Kettlebell) · kettlebell · Glúteos e adutores
  Agachamento Sumô (Smith) · smith · Glúteos e adutores
  Afundo Cruzado (Halter) · dumbbell · Glúteo médio
  Abdução de Quadril em Pé (Máquina) · machine · Glúteo médio
  Abdução Lateral Deitado · bodyweight · Glúteo médio
  Abdução Ostra (Elástico) · band · Glúteo médio
  Hidrante · bodyweight · Glúteo médio
Adutores (adductors):
  Adução de Quadril (Elástico) · band · Adutores (parte interna da coxa)
  Adução Lateral Deitado · bodyweight · Adutores (parte interna da coxa)
Panturrilhas (calves):
  Panturrilha em Pé · bodyweight · Gastrocnêmio
  Panturrilha em Pé (Halter) · dumbbell · Gastrocnêmio
  Panturrilha em Pé (Barra) · barbell · Gastrocnêmio
  Panturrilha Sentado (Halter) · dumbbell · Sóleo
  Panturrilha no Hack (Máquina) · machine · Gastrocnêmio
  Panturrilha Burrico (Máquina) · machine · Gastrocnêmio
  Elevação de Ponta dos Pés · bodyweight · Tibial anterior
Corpo inteiro (fullBody):
  Arremesso (Barra) · barbell · Corpo inteiro (potência)
  Arranco (Barra) · barbell · Corpo inteiro (potência)
  Arranco (Halter) · dumbbell · Corpo inteiro (potência)
  Clean (Kettlebell) · kettlebell · Corpo inteiro (potência)
  Thruster (Kettlebell) · kettlebell · Pernas e ombros
  Kettlebell Swing Unilateral · kettlebell · Glúteos e posteriores (potência)
"""
}
