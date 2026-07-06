#!/usr/bin/env bash
# SessionStart hook: inject the list of connected MCP servers so
# integration-first thinking is grounded in what is actually available.
out=$(timeout 10 claude mcp list 2>/dev/null | head -40)
if [ -n "$out" ]; then
  printf 'Connected MCP servers (integration-scan starts here):\n%s\n' "$out"
fi
exit 0
