#!/bin/zsh
set -euo pipefail

controller='fliggy-agents/build/src/FliggyAgents/FliggyAgentsController.swift'
walker='fliggy-agents/build/src/FliggyAgents/WalkerCharacter.swift'

fail=0

if grep -Fq 'Double.random(in: 5.0...12.0)' "$walker"; then
  echo 'Recurring walk pauses are still too long; expected the idle gap to be shorter than 5...12 seconds.' >&2
  fail=1
fi

for sleepy_start in \
  'Double.random(in: 8.0...14.0)' \
  'Double.random(in: 4.0...9.0)' \
  'Double.random(in: 2.0...7.0)'; do
  if grep -Fq "$sleepy_start" "$controller"; then
    echo "Initial character stagger is still too sleepy; found startup delay range: $sleepy_start" >&2
    fail=1
  fi
done

if [[ $fail -ne 0 ]]; then
  echo 'character_walk_cadence_regression_test: FAIL' >&2
  exit 1
fi

echo 'character_walk_cadence_regression_test: PASS'
