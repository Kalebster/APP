#!/usr/bin/env python3
"""The interface tests of the CI, split among its machines.

ci/ui-test-shards.json assigns every interface test to exactly one part, with the time it took in
recent runs; each part runs on its own machine. This script:

  arguments   prints the xcodebuild arguments of one part, or of the short diagnostic run (the tests
              and repetitions typed when the run was started by hand, read from the environment
              variables TESTES and REPETICOES and validated here, never placed in a command);
  enumerated  reads the list of interface tests that xcodebuild found in the built test bundle,
              writes it in a plain form and fails if it differs from the parts;
  executed    reads the log of one part and writes which tests ran there, with result and time;
  complete    fails unless every test of the bundle ran exactly once, in its own part, and passed;
  balance     proposes a new split from the times of one or more runs (the parts are not changed).

Only the standard library is used, so it runs on the macOS and on the Ubuntu machines as they come.
"""

import argparse
import json
import os
import re
import statistics
import sys

SHARDS_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "ui-test-shards.json")
TARGET = "IronFlowUITests"
# "Class/testMethod": the form used in the parts and in -only-testing.
TEST_ID = re.compile(r"^[A-Za-z][A-Za-z0-9_]*/test[A-Za-z0-9_]*$")
# What may be typed for the short run: a test ("Class/testMethod") or a whole class ("Class").
REQUESTED = re.compile(r"^[A-Za-z][A-Za-z0-9_]*(/test[A-Za-z0-9_]*)?$")
MAX_REQUESTED = 20
MAX_REPETITIONS = 10
CASE = re.compile(r"Test Case '-\[(\w+)\.(\w+) (\w+)\]' (started|passed|failed|skipped)(?: \(([\d.]+) seconds\))?")


class Problem(Exception):
    """A check that failed; its message says what to fix."""


def fail(message):
    raise Problem(message)


# MARK: - The parts

def load_parts(path=SHARDS_PATH):
    """{part: {test: seconds}}, refusing a test listed twice in the same part (json would keep only one)."""

    def no_duplicates(pairs):
        keys = [key for key, _ in pairs]
        repeated = sorted({key for key in keys if keys.count(key) > 1})
        if repeated:
            fail(f"{os.path.basename(path)}: listed more than once in the same part: {', '.join(repeated)}")
        return dict(pairs)

    with open(path) as f:
        data = json.load(f, object_pairs_hook=no_duplicates)
    parts = data.get("parts")
    if not isinstance(parts, dict) or not parts:
        fail(f"{os.path.basename(path)}: no parts")
    for part, tests in parts.items():
        if not isinstance(tests, dict) or not tests:
            fail(f"{os.path.basename(path)}: part {part} has no tests")
        for test, seconds in tests.items():
            if not TEST_ID.match(test):
                fail(f"{os.path.basename(path)}: '{test}' in part {part} is not Class/testMethod")
            if not isinstance(seconds, (int, float)) or seconds <= 0:
                fail(f"{os.path.basename(path)}: '{test}' in part {part} has no time")
    owners = {}
    for part, tests in parts.items():
        for test in tests:
            owners.setdefault(test, []).append(part)
    repeated = {test: owners[test] for test in owners if len(owners[test]) > 1}
    if repeated:
        fail("In more than one part: " + "; ".join(f"{test} (parts {', '.join(p)})" for test, p in sorted(repeated.items())))
    return parts


def owner_of(parts):
    return {test: part for part, tests in parts.items() for test in tests}


def lightest_part(parts):
    return min(parts, key=lambda part: (sum(parts[part].values()), part))


# MARK: - xcodebuild arguments

def requested_tests(text, known):
    """The tests typed for the short run, validated: names only, each one an interface test or class."""
    items = [item for item in re.split(r"[\s,]+", text.strip()) if item]
    if not items:
        fail("No test given. Type tests as Class/testMethod or Class, separated by spaces or commas.")
    if len(items) > MAX_REQUESTED:
        fail(f"{len(items)} items given; at most {MAX_REQUESTED}.")
    classes = {test.split("/")[0] for test in known}
    chosen = []
    for item in items:
        if not REQUESTED.match(item):
            # Not echoed: it may hold anything that was typed.
            fail(f"Item {items.index(item) + 1} is not a test name (Class/testMethod or Class, letters, digits and _ only).")
        if item not in known and item not in classes:
            fail(f"'{item}' is not an interface test or class listed in ci/ui-test-shards.json.")
        if item not in chosen:
            chosen.append(item)
    return chosen


def repetitions(text):
    text = (text or "").strip()
    if not text:
        return 1
    if not re.fullmatch(r"[0-9]{1,2}", text) or not 1 <= int(text) <= MAX_REPETITIONS:
        fail(f"Repetições must be a whole number from 1 to {MAX_REPETITIONS} (or empty, which means 1).")
    return int(text)


def arguments(args):
    parts = load_parts()
    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if args.part == "diagnostico":
        chosen = requested_tests(os.environ.get("TESTES", ""), owner_of(parts))
        times = repetitions(os.environ.get("REPETICOES", ""))
        lines = [f"-only-testing:{TARGET}/{item}" for item in chosen]
        if times > 1:
            lines += ["-test-iterations", str(times)]
        report = [
            "## Rodada curta de diagnóstico",
            "",
            "**Não vale como o CI verde de uma etapa:** antes de cada PR e de cada merge, o CI completo é obrigatório. "
            "Esta rodada não roda os testes de unidade, o build Release nem a conferência dos testes, e não publica screenshots.",
            "",
            f"- Testes: {', '.join(f'`{item}`' for item in chosen)}",
            f"- Repetições: {times}",
        ]
    else:
        if (os.environ.get("REPETICOES") or "").strip():
            fail("Repetições only apply to the short run (with tests typed); the full run runs each test once.")
        if args.part not in parts:
            fail(f"Part {args.part} is not in ci/ui-test-shards.json (parts: {', '.join(sorted(parts))}).")
        tests = sorted(parts[args.part])
        lines = [f"-only-testing:{TARGET}/{test}" for test in tests]
        seconds = sum(parts[args.part].values())
        report = [f"## Parte {args.part} dos testes de interface", "", f"{len(tests)} testes, previsto {seconds / 60:.1f} min."]
    with open(args.output, "w") as f:
        f.write("\n".join(lines) + "\n")
    print("\n".join(lines))
    if summary:
        with open(summary, "a") as f:
            f.write("\n".join(report) + "\n\n")


# MARK: - Tests in the bundle

def tests_in_enumeration(data):
    """Every Class/testMethod of the interface target in xcodebuild's -enumerate-tests JSON. The shape is
    walked loosely: an identifier with the whole path, or a test name under the class that holds it."""
    found = set()
    full = re.compile(r"^(?:" + TARGET + r"/)?([A-Za-z][A-Za-z0-9_]*)/(test[A-Za-z0-9_]*)(?:\(\))?$")
    method = re.compile(r"^(test[A-Za-z0-9_]*)(?:\(\))?$")
    plain = re.compile(r"^[A-Za-z][A-Za-z0-9_]*$")

    def walk(node, names):
        if isinstance(node, list):
            for child in node:
                walk(child, names)
            return
        if not isinstance(node, dict):
            return
        own = [node.get(key) for key in ("identifier", "name") if isinstance(node.get(key), str)]
        for value in own:
            match = full.match(value)
            if match:
                found.add(f"{match.group(1)}/{match.group(2)}")
                break
            match = method.match(value)
            classes = [name for name in names if plain.match(name) and name not in (TARGET,) and not name.startswith("test")]
            if match and classes:
                found.add(f"{classes[-1]}/{match.group(1)}")
                break
        for value in node.values():
            if isinstance(value, (list, dict)):
                walk(value, names + own[:1])

    walk(data, [])
    return found


def enumerated(args):
    with open(args.raw) as f:
        data = json.load(f)
    errors = data.get("errors") if isinstance(data, dict) else None
    if errors:
        fail(f"xcodebuild reported errors while listing the tests: {json.dumps(errors)[:2000]}")
    tests = sorted(tests_in_enumeration(data))
    if not tests:
        fail("No interface test found in the list from xcodebuild. Start of the list: " + json.dumps(data)[:2000])
    with open(args.output, "w") as f:
        json.dump({"tests": tests}, f, indent=2)
    print(f"{len(tests)} interface tests in the built bundle.")
    compare_with_parts(set(tests), load_parts())
    print("Every interface test of the bundle is in exactly one part.")


def compare_with_parts(tests, parts):
    owners = owner_of(parts)
    missing = sorted(tests - set(owners))
    unknown = sorted(set(owners) - tests)
    problems = []
    if missing:
        problems.append(
            f"In no part ({len(missing)}): {', '.join(missing)}. Add each one to ci/ui-test-shards.json, "
            f"in the part with the least time (now part {lightest_part(parts)}), with its time from the CI."
        )
    if unknown:
        problems.append(f"In a part but not in the bundle ({len(unknown)}): {', '.join(unknown)}. Remove them from ci/ui-test-shards.json.")
    if problems:
        fail("\n".join(problems))


# MARK: - Tests that ran

def cases_in_log(text):
    cases, current = [], None
    for line in text.splitlines():
        match = CASE.search(line)
        if not match:
            continue
        if match.group(1) != TARGET:
            continue
        test = f"{match.group(2)}/{match.group(3)}"
        if match.group(4) == "started":
            current = {"test": test, "result": None, "seconds": None}
            cases.append(current)
        elif current is not None and current["test"] == test and current["result"] is None:
            current["result"] = match.group(4)
            current["seconds"] = float(match.group(5)) if match.group(5) else None
    return cases


def executed(args):
    try:
        with open(args.log, errors="replace") as f:
            text = f.read()
    except OSError:
        text = ""
    cases = cases_in_log(text)
    with open(args.output, "w") as f:
        json.dump({"part": args.part, "cases": cases}, f, indent=2)
    passed = sum(case["result"] == "passed" for case in cases)
    print(f"Part {args.part}: {len(cases)} test cases in the log, {passed} passed.")


def read_executed(folder):
    """{part: cases} from every ui-tests-executed.json under `folder` (one per part's artifact)."""
    runs = {}
    for root, _, files in os.walk(folder):
        for name in files:
            if name == "ui-tests-executed.json":
                with open(os.path.join(root, name)) as f:
                    data = json.load(f)
                part = str(data.get("part"))
                if part in runs:
                    fail(f"Two lists of executed tests for part {part}.")
                runs[part] = data.get("cases") or []
    return runs


def complete(args):
    parts = load_parts()
    owners = owner_of(parts)
    problems = []
    try:
        with open(args.enumerated) as f:
            bundle = set(json.load(f)["tests"])
    except (OSError, ValueError, KeyError):
        bundle = None
        problems.append("The list of tests in the built bundle is missing (the unit tests job did not produce it).")
    if bundle is not None:
        try:
            compare_with_parts(bundle, parts)
        except Problem as problem:
            problems.append(str(problem))
    expected = bundle if bundle is not None else set(owners)

    runs = read_executed(args.executed)
    for part in sorted(set(parts) - set(runs)):
        problems.append(f"Part {part}: no list of executed tests (the machine did not finish or did not upload it).")
    for part in sorted(set(runs) - set(parts)):
        problems.append(f"Part {part} ran, but it is not in ci/ui-test-shards.json.")

    seen = {}
    rows = []
    for part, cases in sorted(runs.items()):
        for case in cases:
            seen.setdefault(case["test"], []).append(part)
            rows.append((case["test"], part, case["result"], case["seconds"]))
    twice = {test: where for test, where in seen.items() if len(where) > 1}
    if twice:
        problems.append("Ran more than once: " + "; ".join(f"{test} (parts {', '.join(where)})" for test, where in sorted(twice.items())))
    not_run = sorted(expected - set(seen))
    if not_run:
        problems.append(f"Did not run ({len(not_run)}): {', '.join(not_run)}")
    extra = sorted(set(seen) - expected)
    if extra:
        problems.append(f"Ran but not expected: {', '.join(extra)}")
    elsewhere = sorted(test for test, where in seen.items() if test in owners and owners[test] not in where)
    if elsewhere:
        problems.append(f"Ran outside their part: {', '.join(elsewhere)}")
    not_passed = sorted(f"{test} ({result or 'sem resultado'})" for test, _, result, _ in rows if result != "passed")
    if not_passed:
        problems.append(f"Did not pass ({len(not_passed)}): {', '.join(not_passed)}")

    lines = ["## Testes de interface completos", ""]
    lines.append(f"- Testes no pacote compilado: {len(bundle) if bundle is not None else 'indisponível'}")
    lines.append(f"- Testes executados: {len(rows)}, em {len(runs)} partes; passaram {sum(r[2] == 'passed' for r in rows)}")
    lines.append("")
    lines.append("| Parte | Testes | Previsto | Medido |")
    lines.append("|---|---|---|---|")
    for part in sorted(set(parts) | set(runs)):
        planned = sum(parts.get(part, {}).values())
        measured = sum(case["seconds"] or 0 for case in runs.get(part, []))
        lines.append(f"| {part} | {len(runs.get(part, []))} | {planned:.0f} s | {measured:.0f} s |")
    lines.append("")
    if problems:
        lines.append("**Problemas:**")
        lines.append("")
        lines.extend(f"- {problem}" for problem in problems)
    else:
        lines.append("Cada teste do pacote rodou exatamente uma vez, na parte dele, e passou.")
    lines.append("")
    lines.append("| Teste | Parte | Resultado | Duração |")
    lines.append("|---|---|---|---|")
    for test, part, result, seconds in sorted(rows):
        lines.append(f"| {test} | {part} | {result or 'sem resultado'} | {'' if seconds is None else f'{seconds:.1f} s'} |")
    report = "\n".join(lines) + "\n"
    print(report)
    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a") as f:
            f.write(report)
    if problems:
        fail(f"{len(problems)} problem(s) with the interface tests; see above.")


# MARK: - A new split

def balance(args):
    """Longest tests first, each to the part with the least time so far, using the median time of each
    test in the given lists of executed tests (a test with no time gets the median of all)."""
    times = {}
    for path in args.executed:
        for cases in read_executed(path).values():
            for case in cases:
                if case.get("result") == "passed" and case.get("seconds"):
                    times.setdefault(case["test"], []).append(case["seconds"])
    if not times:
        fail("No times found.")
    median = {test: round(statistics.median(values), 1) for test, values in times.items()}
    tests = set(median) | set(owner_of(load_parts())) if os.path.exists(SHARDS_PATH) and not args.only_runs else set(median)
    default = round(statistics.median(median.values()), 1)
    seconds = {test: median.get(test, default) for test in tests}
    parts = {str(n + 1): {} for n in range(args.parts)}
    for test in sorted(seconds, key=lambda test: (-seconds[test], test)):
        part = min(parts, key=lambda p: (sum(parts[p].values()), int(p)))
        parts[part][test] = seconds[test]
    result = {"parts": {part: dict(sorted(tests.items())) for part, tests in parts.items()}}
    for part, tests in result["parts"].items():
        print(f"Part {part}: {len(tests)} tests, {sum(tests.values()):.0f} s", file=sys.stderr)
    json.dump(result, sys.stdout, indent=2, ensure_ascii=False)
    print()


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    commands = parser.add_subparsers(dest="command", required=True)
    command = commands.add_parser("arguments")
    command.add_argument("--part", required=True)
    command.add_argument("--output", required=True)
    command.set_defaults(run=arguments)
    command = commands.add_parser("enumerated")
    command.add_argument("raw")
    command.add_argument("--output", required=True)
    command.set_defaults(run=enumerated)
    command = commands.add_parser("executed")
    command.add_argument("log")
    command.add_argument("--part", required=True)
    command.add_argument("--output", required=True)
    command.set_defaults(run=executed)
    command = commands.add_parser("complete")
    command.add_argument("--executed", required=True)
    command.add_argument("--enumerated", required=True)
    command.set_defaults(run=complete)
    command = commands.add_parser("balance")
    command.add_argument("executed", nargs="+")
    command.add_argument("--parts", type=int, default=3)
    command.add_argument("--only-runs", action="store_true", help="ignore the tests of the current parts")
    command.set_defaults(run=balance)
    args = parser.parse_args()
    try:
        args.run(args)
    except Problem as problem:
        for line in str(problem).splitlines():
            print(f"::error::{line}")
        sys.exit(1)


if __name__ == "__main__":
    main()
