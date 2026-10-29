#!/usr/bin/env bash
missing=()
for tool in datum-mcp datumctl; do
  command -v "$tool" >/dev/null 2>&1 || missing+=("$tool")
done
[ ${#missing[@]} -eq 0 ] && exit 0

echo "The datum-cloud plugin could not find ${missing[*]} on PATH."
echo "If the user works with Datum Cloud in this session, tell them once and"
echo "follow the datum-cloud:sign-in skill to install it. datum-mcp's tools"
echo "stay unavailable until it is installed and Claude Code is restarted."
