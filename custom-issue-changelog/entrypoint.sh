#!/bin/bash
set -e

REPO=${1:-$GITHUB_REPOSITORY}
LABEL_CONFIG_JSON=$2
MILESTONE_VERSION=$3

if [ -n "$REPO_B_TOKEN" ]; then
  echo "$REPO_B_TOKEN" | gh auth login --with-token
else
  echo "$GITHUB_TOKEN" | gh auth login --with-token
fi

if [ -z "$MILESTONE_VERSION" ]; then
  TAG_NAME="${GITHUB_REF#refs/tags/}"
  MILESTONE_VERSION="${TAG_NAME#v}"
fi

echo "## Changelog for v$MILESTONE_VERSION" > changelog.md
echo "" >> changelog.md

LABEL_COUNT=$(echo "$LABEL_CONFIG_JSON" | jq '. | length')

for i in $(seq 0 $(($LABEL_COUNT - 1))); do
  LABEL_NAME=$(echo "$LABEL_CONFIG_JSON" | jq -r ".[$i].label")
  TEMPLATE=$(echo "$LABEL_CONFIG_JSON" | jq -r ".[$i].template")
  SECTION_TITLE=$(echo "$LABEL_CONFIG_JSON" | jq -r ".[$i].section_title")

  echo "### $SECTION_TITLE" >> changelog.md
  echo "" >> changelog.md

  ISSUES=$(gh issue list --repo "$REPO" --milestone "$MILESTONE_VERSION" --state closed --label "$LABEL_NAME" --json number,title --jq '.[]')

  if [ -z "$ISSUES" ]; then
    echo "_No issues found for label $LABEL_NAME_" >> changelog.md
  else
    echo "$ISSUES" | jq -c '.' | while read -r issue; do
      NUMBER=$(echo "$issue" | jq '.number')
      TITLE=$(echo "$issue" | jq -r '.title')
      ENTRY=$(echo "$TEMPLATE" | sed "s/\$NUMBER/$NUMBER/g" | sed "s/\$TITLE/$TITLE/g")
      echo "$ENTRY" >> changelog.md
    done
  fi

  echo "" >> changelog.md
done

cat changelog.md