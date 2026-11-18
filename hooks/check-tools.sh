#!/usr/bin/env bash
command -v datumctl >/dev/null 2>&1 && exit 0

echo "The datum-cloud plugin could not find datumctl on PATH."
echo "If the user works with Datum Cloud in this session, tell them once and"
echo "follow the datum-cloud:sign-in skill to install it."
