#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
git config core.hooksPath .githooks
git config push.followTags true
printf '%s\n' 'Version hooks enabled. Initial commit is 1.0.0; each subsequent commit increments the patch.'
