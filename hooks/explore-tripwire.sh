#!/usr/bin/env bash
# Serial-exploration tripwire ("delegate breadth, keep judgment").
#   explore-tripwire.sh baseline — SessionStart: record the main transcript
#                                  path for this session, zero the counter
#   explore-tripwire.sh count    — PostToolUse Read|Grep|Glob: increment the
#                                  counter; every THRESHOLD consecutive calls,
#                                  inject a fan-out nudge as additionalContext
#   explore-tripwire.sh reset    — PostToolUse Agent/Task/Edit/Write/etc.:
#                                  zero the counter (the model delegated or
#                                  moved from exploring to implementing)
set -u
mode="${1:-count}"
input=$(cat)
sid=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
tp=$(printf '%s' "$input" | jq -r '.transcript_path // empty' 2>/dev/null)
[ -n "$sid" ] || exit 0
dir="$HOME/.claude/cache/explore-tripwire"
threshold=7

mkdir -p "$dir" 2>/dev/null || exit 0

case "$mode" in
  baseline)
    find "$dir" -type f -mtime +7 -delete 2>/dev/null
    printf '%s' "$tp" > "$dir/$sid.transcript"
    printf '0' > "$dir/$sid.count"
    ;;

  reset)
    printf '0' > "$dir/$sid.count"
    ;;

  count)
    # Subagent tool calls report a sidechain transcript path — never count
    # or nag those; scouts exist to read serially. If no baseline transcript
    # was recorded (plugin installed mid-session), count everything rather
    # than nothing: a false nudge is cheaper than a silent tripwire.
    main_tp=$(cat "$dir/$sid.transcript" 2>/dev/null || true)
    if [ -n "$main_tp" ] && [ -n "$tp" ] && [ "$tp" != "$main_tp" ]; then
      exit 0
    fi
    n=$(cat "$dir/$sid.count" 2>/dev/null || printf '0')
    case "$n" in *[!0-9]* | "") n=0 ;; esac
    n=$((n + 1))
    printf '%s' "$n" > "$dir/$sid.count"
    if [ $((n % threshold)) -eq 0 ]; then
      msg="Serial-exploration tripwire: $n consecutive Read/Grep/Glob calls \
without dispatching a subagent. Per operating principle 4 (delegate breadth, \
keep judgment), do one of two things now: (a) fan out scout agents — one \
bounded question each, ALL dispatched in a single message (see the fan-out \
skill) — or (b) state explicitly in your next response why this task is \
small enough (roughly: one subsystem, ~5 files) that serial reading is the \
right call. Continuing to read file-by-file without doing either is the \
exact failure mode this hook exists to catch."
      jq -cn --arg m "$msg" \
        '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:$m}}'
    fi
    ;;
esac
exit 0
