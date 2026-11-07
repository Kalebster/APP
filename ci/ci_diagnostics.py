#!/usr/bin/env python3
"""Diagnostics of one CI job, printed last so they close its log, and added to the run summary.

They only read what earlier steps left (build/*.log, build/diagnostics/ and the exported attachments in
build/screenshots): anything missing is reported as unavailable, and this never changes the result of the
job. Each macOS job runs it for its own steps; the outcome of each step comes from the environment
(BUILD_OUTCOME, SIMULATOR_OUTCOME, UI_TEST_LIST_OUTCOME, UNIT_OUTCOME, UI_OUTCOME, RELEASE_OUTCOME), and
the steps a job does not have are left out. DIAGNOSTICS_TITLE names the job in the title.
"""
import json, os, re, statistics, subprocess
from datetime import datetime

UNAVAILABLE = "indisponível"
lines = []

def add(text=""):
    lines.append(text)

def read_text(path):
    try:
        with open(path, errors="replace") as f:
            return f.read()
    except OSError:
        return None

def read_json(path):
    text = read_text(path)
    try:
        return json.loads(text) if text else None
    except ValueError:
        return None

def command(*args):
    try:
        result = subprocess.run(args, capture_output=True, text=True, timeout=60)
    except (OSError, subprocess.SubprocessError):
        return None
    output = result.stdout.strip()
    return output if result.returncode == 0 and output else None

def seconds(value):
    return UNAVAILABLE if value is None else f"{value:.1f} s"

def table(header, rows):
    add("| " + " | ".join(header) + " |")
    add("|" + "---|" * len(header))
    for row in rows:
        add("| " + " | ".join(str(cell).replace("|", "\\|").replace("\n", " ") for cell in row) + " |")

def section(title, build):
    # Sections are independent: one that cannot be produced is reported, the others still are.
    add()
    add(f"### {title}")
    add()
    try:
        build()
    except Exception as error:
        add(f"{UNAVAILABLE} (falha ao gerar esta seção: {type(error).__name__}: {error})")

def last_match(pattern, text):
    matches = re.findall(pattern, text or "")
    return matches[-1] if matches else None

# Lines written by record-step.sh: "start NAME EPOCH LOAD" and "end NAME exit=N|signal=SIG EPOCH LOAD".
RECORDS = {}
for line in (read_text("build/diagnostics/steps.txt") or "").splitlines():
    parts = line.split()
    if len(parts) == 4 and parts[0] == "start" and parts[2].isdigit():
        RECORDS.setdefault(parts[1], {})["start"] = (int(parts[2]), parts[3])
    elif len(parts) == 5 and parts[0] == "end" and parts[3].isdigit():
        RECORDS.setdefault(parts[1], {})["end"] = (parts[2], int(parts[3]), parts[4])

def duration(name):
    record = RECORDS.get(name, {})
    if "start" in record and "end" in record:
        return record["end"][1] - record["start"][0]
    return None

def recorded(name):
    # What the step's own shell recorded; GitHub's result for the step is shown beside it.
    record = RECORDS.get(name, {})
    if "start" not in record:
        return "sem registro"
    if "end" not in record:
        return "interrompida, sem registro de fim"
    status = record["end"][0]
    if status == "exit=0":
        return "concluída (código 0)"
    if status.startswith("exit="):
        return f"falhou (código {status[5:]})"
    if status.startswith("signal="):
        return f"encerrada pelo sinal {status[7:]}"
    return f"{UNAVAILABLE} ({status})"

def load(name):
    record = RECORDS.get(name, {})
    start = record["start"][1] if "start" in record else "-"
    end = record["end"][2] if "end" in record else "-"
    if start == "-" and end == "-":
        return UNAVAILABLE
    return f"{start} → {end}"

def environment():
    image = " ".join(v for v in (os.environ.get("ImageOS"), os.environ.get("ImageVersion")) if v)
    runner = " ".join(v for v in (os.environ.get("RUNNER_NAME"), os.environ.get("RUNNER_OS"), os.environ.get("RUNNER_ARCH")) if v)
    macos, macos_build = command("sw_vers", "-productVersion"), command("sw_vers", "-buildVersion")
    xcode = command("xcodebuild", "-version")
    cpu = command("sysctl", "-n", "machdep.cpu.brand_string")
    physical, logical = command("sysctl", "-n", "hw.physicalcpu"), command("sysctl", "-n", "hw.logicalcpu")
    memory = command("sysctl", "-n", "hw.memsize")
    rows = [
        ("Imagem do runner", image or UNAVAILABLE),
        ("Runner", runner or UNAVAILABLE),
        ("macOS", f"{macos} ({macos_build})" if macos else UNAVAILABLE),
        ("Xcode", xcode.replace("\n", ", ") if xcode else UNAVAILABLE),
        ("CPU", cpu or UNAVAILABLE),
        ("Núcleos (físicos / lógicos)", f"{physical or UNAVAILABLE} / {logical or UNAVAILABLE}"),
        ("Memória", f"{int(memory) / 2**30:.1f} GB" if memory and memory.isdigit() else UNAVAILABLE),
    ]
    simulator = read_json("build/diagnostics/simulator.json")
    if simulator:
        runtime = simulator.get("runtime") or {}
        rows += [
            ("Simulador", f"{simulator.get('name')} ({simulator.get('udid')})"),
            ("Runtime", f"{runtime.get('name')} ({runtime.get('buildversion')})"),
        ]
    else:
        rows.append(("Simulador", UNAVAILABLE))
    table(["Item", "Valor"], rows)

def in_job(outcome):
    # A step belongs to this job when the job passes its outcome (even "skipped").
    return os.environ.get(outcome) is not None

def steps():
    rows = []
    previous_end = None
    for key, label, outcome in (
        ("build_for_testing", "Compilação para testes", "BUILD_OUTCOME"),
        ("simulator_boot", "Boot do simulador", "SIMULATOR_OUTCOME"),
        ("ui_test_list", "Lista dos testes de interface", "UI_TEST_LIST_OUTCOME"),
        ("unit_tests", "Testes de unidade", "UNIT_OUTCOME"),
        ("ui_tests", "Testes de interface", "UI_OUTCOME"),
        ("build_release", "Compilação Release", "RELEASE_OUTCOME"),
    ):
        if not in_job(outcome):
            continue
        record = RECORDS.get(key, {})
        start = record["start"][0] if "start" in record else None
        gap = seconds(start - previous_end) if start is not None and previous_end is not None else "—"
        rows.append((label, os.environ.get(outcome) or UNAVAILABLE, recorded(key), seconds(duration(key)), load(key), gap))
        if "end" in record:
            previous_end = record["end"][1]
    table(["Etapa", "Resultado no GitHub", "Registro da etapa", "Duração", "Carga de 1 min (início → fim)", "Intervalo desde a etapa anterior"], rows)

def boot():
    simulator = read_json("build/diagnostics/simulator.json") or {}
    rows = [
        ("Estado antes do boot", simulator.get("state") or UNAVAILABLE),
        ("Duração do boot (até o simulador ficar pronto)", seconds(duration("simulator_boot"))),
        ("Registro", recorded("simulator_boot")),
    ]
    booted = read_text("build/diagnostics/booted-devices.txt")
    if booted is None:
        rows.append(("Simuladores ligados antes dos testes", UNAVAILABLE))
    else:
        devices = [line.strip() for line in booted.splitlines() if "(Booted)" in line]
        rows.append(("Simuladores ligados antes dos testes", f"{len(devices)}: " + "; ".join(devices)))
    table(["Medida", "Valor"], rows)

RESULT = r"\*\* (TEST [A-Z ]+?) \*\*"
EXECUTED = r"Executed (\d+) tests?, with (\d+) failures? \((\d+) unexpected\) in ([\d.]+)"

def classify(message):
    lowered = message.lower()
    if "failed to launch" in lowered or "timed out while launching" in lowered:
        return "abertura do app"
    if "failed to synthesize event" in lowered or "keyboard focus" in lowered:
        return "interação com a interface"
    if "crash" in lowered:
        return "app encerrado inesperadamente"
    if "xctassert" in lowered or "expectation failed" in lowered:
        return "verificação do teste"
    return "sem padrão conhecido"

# Test failures only ("File.swift:12: error: …" and Swift Testing "✘ Test …" issues), not the
# app's own error logs, which some tests cause on purpose.
FAILURE = re.compile(r"\.swift:\d+(?::\d+)?: error: |^\s*✘ Test (?!run with)")

def failures(log):
    found = [line.strip() for line in log.splitlines() if FAILURE.search(line)]
    if not found:
        return
    add()
    add(f"Falhas registradas no log ({len(found)}; pré-classificação apenas pelo texto da mensagem):")
    add()
    for line in found[:30]:
        add(f"- [{classify(line)}] `{line[:400]}`")
    if len(found) > 30:
        add(f"- … mais {len(found) - 30} linhas no log completo.")

def unit_tests():
    log = read_text("build/unit-test.log")
    if log is None:
        add(f"{UNAVAILABLE} (sem log: a etapa não foi executada)")
        return
    swift = last_match(r"Test run with (\d+) tests? in (\d+) suites? (passed|failed) after ([\d.]+) seconds(?: with (\d+) issues?)?", log)
    xctest = last_match(EXECUTED, log)
    result = last_match(RESULT, log)
    table(["Medida", "Valor"], [
        ("Swift Testing", f"{swift[0]} testes em {swift[1]} suítes, {swift[2]}, {float(swift[3]):.1f} s, {swift[4] or 0} problemas" if swift else UNAVAILABLE),
        ("XCTest", f"{xctest[0]} testes, {xctest[1]} falhas" if xctest else UNAVAILABLE),
        ("Resultado do xcodebuild", result or UNAVAILABLE),
    ])
    failures(log)

CASE = re.compile(r"Test Case '-\[(\w+)\.(\w+) (\w+)\]' (started|passed|failed|skipped)(?: \(([\d.]+) seconds\))?")
ACTIVITY = re.compile(r"^\s*t =\s+([\d.]+)s\s+(.*?)\s*$")

def parse_cases(log):
    cases, current = [], None
    for line in log.splitlines():
        match = CASE.search(line)
        if match:
            if match.group(4) == "started":
                current = {"suite": match.group(2), "test": match.group(3), "result": None, "duration": None, "activities": []}
                cases.append(current)
            elif current is not None and current["test"] == match.group(3):
                current["result"] = match.group(4)
                current["duration"] = float(match.group(5)) if match.group(5) else None
            continue
        activity = ACTIVITY.match(line)
        if activity and current is not None and current["result"] is None:
            current["activities"].append((float(activity.group(1)), activity.group(2)))
    return cases

def first_at(activities, matches, after=None):
    for time, text in activities:
        if (after is None or time >= after) and matches(text):
            return time
    return None

def launch_metrics(case):
    # XCTest activity times: the app launch and the automation session appear together,
    # from "Launch" to "Setting up automation session"; the log does not separate them.
    activities = case["activities"]
    launch = first_at(activities, lambda text: text.startswith("Launch "))
    automation = first_at(activities, lambda text: text == "Setting up automation session", launch) if launch is not None else None
    idle = first_at(activities, lambda text: text.startswith("Wait for ") and text.endswith(" to idle"), automation) if automation is not None else None
    pause, during, after = None, None, None
    for (time, text), (next_time, next_text) in zip(activities, activities[1:]):
        if pause is None or next_time - time > pause:
            pause, during, after = next_time - time, text, next_text
    return {
        "setup": first_at(activities, lambda text: text == "Set Up"),
        "launched": launch is not None,
        "launch": automation - launch if automation is not None else None,
        "idle": idle - automation if idle is not None else None,
        "pause": pause,
        "during": during,
        "after": after,
    }

def launch_text(metrics):
    if not metrics["launched"]:
        return "sem abertura"
    return seconds(metrics["launch"]) if metrics["launch"] is not None else "não concluída"

def pause_text(metrics):
    if metrics["pause"] is None:
        return UNAVAILABLE
    return f"{seconds(metrics['pause'])} em “{metrics['during'][:80]}”, antes de “{metrics['after'][:80]}”"

def runner_startup(log):
    # From the start of the step to the first interface test (the test runner starting up).
    started = last_match(r"Test Suite 'All tests' started at (\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d+)", log)
    record = RECORDS.get("ui_tests", {})
    if not started or "start" not in record:
        return UNAVAILABLE
    return seconds(datetime.strptime(started, "%Y-%m-%d %H:%M:%S.%f").timestamp() - record["start"][0])

def ui_tests():
    log = read_text("build/ui-test.log")
    if log is None:
        add(f"{UNAVAILABLE} (sem log: a etapa não foi executada)")
        return
    cases = parse_cases(log)
    executed = last_match(EXECUTED, log)
    counted = {result: sum(case["result"] == result for case in cases) for result in ("passed", "failed", "skipped", None)}
    table(["Medida", "Valor"], [
        ("Testes executados (XCTest)", f"{executed[0]} testes, {executed[1]} falhas ({executed[2]} inesperadas), {float(executed[3]):.1f} s" if executed else UNAVAILABLE),
        ("Casos no log", f"{len(cases)}: {counted['passed']} passaram, {counted['failed']} falharam, {counted['skipped']} ignorados, {counted[None]} sem resultado"),
        ("Resultado do xcodebuild", last_match(RESULT, log) or UNAVAILABLE),
        ("Do início da etapa ao primeiro teste", runner_startup(log)),
    ])
    if cases:
        measured = [(case, launch_metrics(case)) for case in cases]
        first_case, first = measured[0]
        add()
        add(f"Primeiro teste: `{first_case['suite']}.{first_case['test']}`")
        add()
        table(["Medida", "Valor"], [
            ("Do início do teste ao Set Up", seconds(first["setup"])),
            ("Da abertura do app à automação pronta", launch_text(first)),
            ("Da automação pronta ao app ocioso", seconds(first["idle"])),
            ("Maior pausa entre atividades", pause_text(first)),
        ])
        others = [(case, metrics) for case, metrics in measured[1:] if metrics["launch"] is not None]
        if others:
            slowest_case, slowest = max(others, key=lambda item: item[1]["launch"])
            median = statistics.median(metrics["launch"] for _, metrics in others)
            add()
            add(f"Demais testes, da abertura do app à automação pronta ({len(others)} com dados): "
                f"mediana {seconds(median)}, máximo {seconds(slowest['launch'])} em `{slowest_case['suite']}.{slowest_case['test']}`.")
        suites = {}
        for case in cases:
            totals = suites.setdefault(case["suite"], [0, 0, 0.0])
            totals[0] += 1
            totals[1] += case["result"] == "failed"
            totals[2] += case["duration"] or 0
        add()
        table(["Grupo", "Testes", "Falhas", "Duração"], [(name, n, failed, seconds(total)) for name, (n, failed, total) in suites.items()])
        add()
        table(["Teste", "Resultado", "Duração", "Abertura → automação", "Maior pausa"], [
            (f"{case['suite']}.{case['test']}", case["result"] or "sem resultado", seconds(case["duration"]), launch_text(metrics), pause_text(metrics))
            for case, metrics in measured
        ])
    failures(log)

def infrastructure():
    # Messages that point to the environment rather than to the app; finding none is not proof.
    markers = ("unable to boot", "failed to boot", "coresimulatorservice", "early unexpected exit",
               "test runner exited", "never began executing", "failed to initialize for ui testing",
               "lost connection", "timed out while launching", "unable to find a destination",
               "crashed", "simulator device failed", "unable to lookup in current state")
    found = []
    for path in ("build/build.log", "build/unit-test.log", "build/ui-test.log", "build/build-release.log"):
        for line in (read_text(path) or "").splitlines():
            if any(marker in line.lower() for marker in markers):
                entry = f"{os.path.basename(path)}: {line.strip()[:300]}"
                if entry not in found:
                    found.append(entry)
    if not found:
        add("Nenhuma marca conhecida de infraestrutura encontrada nos logs (isso não prova que não houve problema de ambiente).")
        return
    for entry in found[:30]:
        add(f"- `{entry}`")
    if len(found) > 30:
        add(f"- … mais {len(found) - 30} linhas.")

def failure_attachments():
    # Text attachments of failed interface tests, from the exported results: the debug
    # descriptions (only the query that failed) and the hierarchy of the app's screen when
    # the test ended, which IronFlowUITestCase attaches (what was on screen, which is what a
    # failure that cannot be reproduced locally needs).
    manifest = read_json("build/screenshots/manifest.json")
    if not isinstance(manifest, list):
        add(f"{UNAVAILABLE} (nenhum anexo exportado)")
        return
    listed = printed = 0
    for test in manifest:
        identifier = test.get("testIdentifier") or test.get("testIdentifierURL") or "?"
        for attachment in test.get("attachments", []):
            name = attachment.get("suggestedHumanReadableName") or ""
            lowered = name.lower()
            hierarchy = "ui hierarchy" in lowered
            if not (attachment.get("isAssociatedWithFailure") or "debug description" in lowered or hierarchy):
                continue
            exported = attachment.get("exportedFileName") or ""
            add(f"- `{identifier}`: `{exported}`")
            listed += 1
            if exported.lower().endswith((".txt", ".log", ".json")) and printed < 1000:
                text = [line[:240] for line in (read_text(os.path.join("build/screenshots", exported)) or "").splitlines()[:150 if hierarchy else 60]]
                add()
                add("```")
                lines.extend(text)
                add("```")
                printed += len(text)
    if listed == 0:
        add("Nenhum anexo associado a falhas.")

def measurements():
    # Values the interface tests measured and kept as attachments named "Medição: ...", printed
    # even when the test passes (the brightness of each screen, of a sheet and of the keyboard).
    manifest = read_json("build/screenshots/manifest.json")
    if not isinstance(manifest, list):
        add(f"{UNAVAILABLE} (nenhum anexo exportado)")
        return
    rows = []
    for test in manifest:
        identifier = test.get("testIdentifier") or test.get("testIdentifierURL") or "?"
        for attachment in test.get("attachments", []):
            name = attachment.get("suggestedHumanReadableName") or ""
            if not name.startswith("Medição"):
                continue
            exported = attachment.get("exportedFileName") or ""
            value = (read_text(os.path.join("build/screenshots", exported)) or UNAVAILABLE).strip()
            rows.append((identifier, re.sub(r"_\d+_[0-9A-Fa-f-]{36}", "", name), value))
    if not rows:
        add("Nenhuma medição registrada.")
        return
    table(["Teste", "Medição", "Valor"], rows)

def builds():
    # xcodebuild -showBuildTimingSummary: the time spent in each kind of task. Tasks run in
    # parallel, so their times can add up to more than the duration of the step.
    for label, path, key, outcome in (("Compilação para testes", "build/build.log", "build_for_testing", "BUILD_OUTCOME"),
                                      ("Compilação Release", "build/build-release.log", "build_release", "RELEASE_OUTCOME")):
        if not in_job(outcome):
            continue
        add(f"**{label}**: duração {seconds(duration(key))}, carga de 1 min {load(key)}")
        add()
        log = read_text(path)
        if log is None:
            add(f"{UNAVAILABLE} (sem log: a etapa não foi executada)")
            add()
            continue
        log_lines = log.splitlines()
        starts = [i for i, line in enumerate(log_lines) if line.strip() == "Build Timing Summary"]
        if not starts:
            add(f"{UNAVAILABLE} (o resumo de tempos não aparece no log)")
            add()
            continue
        summary = []
        for line in log_lines[starts[-1] + 1:]:
            if line.strip():
                summary.append(line.strip())
            if line.startswith("** ") or len(summary) >= 40:
                break
        add("```")
        lines.extend(summary)
        add("```")
        add()

def limitations():
    add("- A abertura do app e a conexão da automação aparecem juntas no log (de “Launch” a “Setting up automation session”).")
    add("- A carga da máquina é a média de 1 minuto no início e no fim de cada etapa, não uma medição contínua.")
    add("- Cada máquina tem os próprios artefatos: build-logs-*, test-results-* e, nas de interface, screenshots-*; o registro do simulador fica no build-logs dela quando algum teste falha.")
    add("- Os tempos das etapas vêm do relógio do runner, com precisão de 1 s.")

title = os.environ.get("DIAGNOSTICS_TITLE")
add(f"## Diagnóstico do CI — {title}" if title else "## Diagnóstico do CI")
section("Ambiente", environment)
section("Etapas", steps)
section("Compilações", builds)
section("Simulador", boot)
if in_job("UNIT_OUTCOME"):
    section("Testes de unidade", unit_tests)
if in_job("UI_OUTCOME"):
    section("Testes de interface", ui_tests)
section("Marcas de infraestrutura", infrastructure)
section("Medições dos testes", measurements)
section("Anexos de falhas", failure_attachments)
section("Limitações", limitations)

report = "\n".join(lines) + "\n"
print(report)
summary = os.environ.get("GITHUB_STEP_SUMMARY")
if summary:
    try:
        with open(summary, "a") as f:
            f.write(report)
    except OSError as error:
        print(f"Não foi possível escrever o resumo da execução: {error}")
