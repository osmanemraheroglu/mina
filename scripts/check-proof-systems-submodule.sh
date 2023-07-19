#!/bin/bash

set -eu

cd src/lib/crypto/proof-systems

CURR=$(git rev-parse HEAD)
# temporarily skip SSL verification (for CI)
#git config http.sslVerify false
git fetch origin
#git config http.sslVerify true


if [ "${BUILDKITE_PULL_REQUEST_BASE_BRANCH}" = "" ]; then
  echo "BUILDKITE_PULL_REQUEST_BASE_BRANCH env variable is not set. Are you triggered build manually?"
  echo "If yes, then rerun it using custom build with environment variables:"
  echo "BUILDKITE_PULL_REQUEST_BASE_BRANCH={your_target_branch}"
  exit 1
fi

declare -A BRANCH_MAPPING=(
  ["rampup"]="compatible" 
  ["berkeley"]="berkeley"
  ["develop"]="develop"
  ["izmir"]="master"
  # Default case
  [${BUILDKITE_PULL_REQUEST_BASE_BRANCH}]=${BUILDKITE_PULL_REQUEST_BASE_BRANCH}
)

function in_branch {
  if git rev-list origin/$1 | grep -q $CURR; then
    echo "Proof systems submodule commit is an ancestor of $1"
    true
  else
    false
  fi
}

BRANCH="${BRANCH_MAPPING[${BUILDKITE_PULL_REQUEST_BASE_BRANCH}]}"

if (! in_branch ${BRANCH}); then
  echo "Proof-systems submodule commit is NOT an ancestor of ${BRANCH} branch"
  exit 1
fi