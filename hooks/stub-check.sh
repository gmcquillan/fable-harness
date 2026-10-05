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

# Generated protobuf code carries fixed "not implemented"/TODO-shaped
# boilerplate (e.g. protoc-gen-go-grpc's Unimplemented*Server stubs) that
# is never hand-written and never something an agent can "finish" — only
# regenerate. Exclude well-known generated-protobuf filename suffixes
# across ecosystems from both the diff scan and the untracked-file scan.
# These suffixes are specific enough to protobuf codegen that they should
# not collide with hand-written source in any language.
gen_pb_pathspecs=(
  ':(glob,exclude)**/*.pb.go'
  ':(glob,exclude)**/*_grpc.pb.go'
  ':(glob,exclude)**/*.pb.gw.go'
  ':(glob,exclude)**/*_pb2.py'
  ':(glob,exclude)**/*_pb2_grpc.py'
  ':(glob,exclude)**/*.pb.cc'
  ':(glob,exclude)**/*.pb.h'
  ':(glob,exclude)**/*.pb.swift'
  ':(glob,exclude)**/*_pb.rb'
  ':(glob,exclude)**/*.pb.dart'
)
is_generated_pb_path() {
  case "$1" in
    *.pb.go|*_grpc.pb.go|*.pb.gw.go|*_pb2.py|*_pb2_grpc.py|*.pb.cc|*.pb.h|*.pb.swift|*_pb.rb|*.pb.dart)
      return 0 ;;
    *)
      return 1 ;;
  esac
}

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

# Lines added since the session baseline (committed or not). Generated
# protobuf files are excluded via pathspec — see is_generated_pb_path above.
diff_hits=""
if [ -n "$base" ]; then
  diff_hits=$(git diff "$base" --unified=0 -- . "${gen_pb_pathspecs[@]}" 2>/dev/null \
    | grep -E '^\+[^+]' | grep -vE '^\+\+\+' || true)

  # Work merged/pulled in from upstream since the baseline is not "added this
  # session" — it shows up in the diff only because HEAD moved past $base.
  # Subtract every line the default branch introduced since the merge-base.
  if [ -n "$diff_hits" ]; then
    upstream_added=""
    for ref in refs/remotes/origin/HEAD refs/remotes/origin/main refs/remotes/origin/master \
               refs/heads/main refs/heads/master; do
      git rev-parse --verify -q "$ref^{commit}" >/dev/null 2>&1 || continue
      mb=$(git merge-base "$base" "$ref" 2>/dev/null) || continue
      upstream_added="$upstream_added
$(git diff "$mb" "$ref" --unified=0 -- . "${gen_pb_pathspecs[@]}" 2>/dev/null \
        | grep -E '^\+[^+]' | grep -vE '^\+\+\+' || true)"
    done
    upstream_added=$(printf '%s\n' "$upstream_added" | sed '/^$/d')
    if [ -n "$upstream_added" ]; then
      diff_hits=$(printf '%s\n' "$diff_hits" | grep -vxF -f <(printf '%s\n' "$upstream_added") || true)
    fi
  fi
fi

# Untracked files are invisible to diff — grep only ones NEW this session,
# skipping generated-protobuf paths the same way.
snap="$dir/$sid.untracked"
all_untracked=$(git ls-files --others --exclude-standard 2>/dev/null | sed '/^$/d')
if [ -n "$sid" ] && [ -f "$snap" ]; then
  new_untracked=$(printf '%s\n' "$all_untracked" | grep -vxF -f "$snap" || true)
else
  new_untracked="$all_untracked"
fi
filtered_untracked=""
if [ -n "$new_untracked" ]; then
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    is_generated_pb_path "$f" && continue
    filtered_untracked="$filtered_untracked
$f"
  done <<< "$new_untracked"
fi
untracked_hits=""
if [ -n "$filtered_untracked" ]; then
  untracked_hits=$(printf '%s\n' "$filtered_untracked" | tr '\n' '\0' \
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
