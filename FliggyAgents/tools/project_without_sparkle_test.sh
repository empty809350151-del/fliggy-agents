#!/bin/zsh
set -euo pipefail
project='fliggy-agents/build/src/fliggy-agents.xcodeproj/project.pbxproj'
forbidden=(
  'Sparkle in Frameworks'
  'XCRemoteSwiftPackageReference "Sparkle"'
  'productName = Sparkle;'
)
fail=0
for needle in "${forbidden[@]}"; do
  if grep -Fq "$needle" "$project"; then
    echo "Found forbidden Sparkle reference: $needle" >&2
    fail=1
  fi
done
if [[ $fail -ne 0 ]]; then
  echo 'project_without_sparkle_test: FAIL' >&2
  exit 1
fi
echo 'project_without_sparkle_test: PASS'
