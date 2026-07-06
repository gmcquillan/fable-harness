#!/usr/bin/env bash
# Completion-integrity hook ("done means done").
#   stub-check.sh baseline  — SessionStart: record HEAD + untracked-file
#                             snapshot for this session
#   stub-check.sh check     — Stop: block turn if content added this session
#                             contains silent stub markers.
# Escape hatch: markers written as "TODO(tracked): <ref>" pass.
set -u
mode="${1:-check}"
input=$(cat)
sid=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
dir="$HOME/.claude/cache/stub-baselines"

# Outside a git repo there is nothing to diff — no-op.
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

if [ "$mode" = "baseline" ]; then
  mkdir -p "$dir"
  find "$dir" -type f -mtime +7 -delete 2>/dev/null
  if [ -n "$sid" ]; then
    # A repo with no commits has no baseline commit; record none rather
    # than a bogus one (check mode then relies on the snapshot alone).
    git rev-parse --verify 'HEAD^{commit}' 2>/dev/null > "$dir/$sid" \
      || rm -f "$dir/$sid"
    # Snapshot untracked files so pre-existing ones never trigger checks.
    git ls-files --others --exclude-standard 2>/dev/null > "$dir/$sid.untracked"
  fi
  exit 0
fi

# check mode. Never re-block a continuation triggered by this hook.
active=$(printf '%s' "$input" | jq -r '.stop_hook_active // false' 2>/dev/null)
[ "$active" = "true" ] && exit 0

base=""
[ -n "$sid" ] && base=$(cat "$dir/$sid" 2>/dev/null)
if [ -z "$base" ] || ! git cat-file -e "$base" 2>/dev/null; then
  base=$(git rev-parse --verify 'HEAD^{commit}' 2>/dev/null) || base=""
fi

pattern='\b(TODO|FIXME|XXX|HACK)\b|unimplemented!|todo!\(\)|NotImplementedError|[Nn]ot[ _-]?[Ii]mplemented|(#|//)[[:space:]]*stub\b'

# Lines added since the session baseline (committed or not).
diff_hits=""
if [ -n "$base" ]; then
  diff_hits=$(git diff "$base" --unified=0 2>/dev/null \
    | grep -E '^\+[^+]' | grep -vE '^\+\+\+' || true)
fi

# Untracked files are invisible to diff — grep only ones NEW this session.
snap="$dir/$sid.untracked"
all_untracked=$(git ls-files --others --exclude-standard 2>/dev/null | sed '/^$/d')
if [ -n "$sid" ] && [ -f "$snap" ]; then
  new_untracked=$(printf '%s\n' "$all_untracked" | grep -vxF -f "$snap" || true)
else
  new_untracked="$all_untracked"
fi
untracked_hits=""
if [ -n "$new_untracked" ]; then
  untracked_hits=$(printf '%s\n' "$new_untracked" | tr '\n' '\0' \
    | xargs -0 -r grep -HnE "$pattern" -- 2>/dev/null || true)
fi

hits=$(printf '%s\n%s\n' "$diff_hits" "$untracked_hits" \
  | grep -E "$pattern" | grep -v 'TODO(tracked):')

if [ -n "$hits" ]; then
  {
    echo "BLOCKED — silent incompleteness markers were added this session:"
    echo "$hits" | head -20
    echo ""
    echo "Per 'done means done' (CLAUDE.md principle 5): implement each of"
    echo "these before finishing, or convert to 'TODO(tracked): <issue/task"
    echo "ref>' AND surface it in your final summary."
    [ -n "$base" ] && echo "To locate: git diff $base | grep -nE '<marker>'"
  } >&2
  exit 2
fi
exit 0
