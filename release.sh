#!/usr/bin/env bash
set -e

if [ -z "$1" ]; then
  echo Need a version number
  echo "Example: $(basename "$0") v0.0.1"
  exit 1
fi

# Using Perl because of BSD vs GNU sed
perl -i -pe "s/__VERSION__/$1/g" canary.sh
git commit --allow-empty -m "$1"
git tag -a "$1" -m "$1"
git push origin master --follow-tags
