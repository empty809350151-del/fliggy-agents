#!/bin/zsh
set -euo pipefail

controller='fliggy-agents/build/src/FliggyAgents/FliggyAgentsController.swift'
walker='fliggy-agents/build/src/FliggyAgents/WalkerCharacter.swift'

fail=0

if ! grep -Fq 'showExternalNotificationBubble(title: "", body: message.fullText' "$controller"; then
  echo 'Expected proactive bubbles to render message.fullText without title/body parsing.' >&2
  fail=1
fi

if ! grep -Fq 'bubbleMeasurementSlack' "$walker"; then
  echo 'Expected bubble width calculation to include a measurement slack constant.' >&2
  fail=1
fi

if [[ $fail -ne 0 ]]; then
  echo 'proactive_bubble_display_regression_test: FAIL' >&2
  exit 1
fi

echo 'proactive_bubble_display_regression_test: PASS'
