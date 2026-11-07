# Sourced by the timed CI steps: `source ci/record-step.sh NAME`. It appends to build/diagnostics/steps.txt
# a "start" line and, when the shell that sourced it exits, an "end" line with the exit code, or with the
# signal when the step was stopped by one (as when the job is cancelled). A step killed outright leaves
# only its "start" line. Each line ends with the machine's 1-minute load average ("-" when unavailable).
# Recording never fails a step. ci/ci_diagnostics.py reads these lines.
mkdir -p build/diagnostics 2>/dev/null || true
step_name="$1"
step_signal=""
step_record() {
  local load
  load="$(sysctl -n vm.loadavg 2>/dev/null | awk '{print $2}')" || true
  echo "$* $(date +%s) ${load:--}" >> build/diagnostics/steps.txt || true
}
step_end() {
  local status=$?
  if [ -n "$step_signal" ]; then
    step_record end "$step_name" "signal=$step_signal"
  else
    step_record end "$step_name" "exit=$status"
  fi
}
trap 'step_signal=INT; exit 130' INT
trap 'step_signal=TERM; exit 143' TERM
trap step_end EXIT
step_record start "$step_name"
