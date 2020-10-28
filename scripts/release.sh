#!/usr/bin/env bash
set -e

git commit --allow-empty -m "$1"
git tag -a "$1" -m "$1"
./scripts/changelog.sh
git add CHANGELOG.md
git commit -m 'docs: changelog'
# git push origin master --follow-tags
