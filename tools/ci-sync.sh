#!/usr/bin/env bash
#
# Mirror upstream's main and development branches into this fork.
#
# These branches are kept as exact copies of dan-snelson/Mac-Health-Check; WKU never commits to
# them. If a fork branch can't be fast-forwarded (upstream rewrote history), its current commit is
# saved as a backup/<branch>-<date> tag before the branch is reset to upstream.
#
# Needs SYNC_TOKEN: a fine-grained personal access token for this repository with
# "Contents: Read and write" and "Workflows: Read and write". (GitHub's built-in GITHUB_TOKEN
# can't push commits that touch .github/workflows, and upstream has its own workflows.)
#
# Usage: SYNC_TOKEN=... tools/ci-sync.sh      DRY_RUN=true shows what would happen.

set -euo pipefail

UPSTREAM_URL="https://github.com/dan-snelson/Mac-Health-Check.git"
FORK_REPO="${GITHUB_REPOSITORY:-bigdoodr/Mac-Health-Check}"
DRY_RUN="${DRY_RUN:-false}"
BRANCHES=(main development)

if [[ -z "${SYNC_TOKEN:-}" ]]; then
    echo "::warning::SYNC_TOKEN secret is not set; skipping the main/development mirror (builds don't need it)."
    exit 0
fi

forkURL="https://x-access-token:${SYNC_TOKEN}@github.com/${FORK_REPO}.git"
workDir="$( mktemp -d )"
trap 'rm -rf "${workDir}"' EXIT

git -C "${workDir}" init -q
git -C "${workDir}" fetch -q --filter=blob:none "${UPSTREAM_URL}" \
    "+refs/heads/main:refs/remotes/upstream/main" "+refs/heads/development:refs/remotes/upstream/development"
git -C "${workDir}" fetch -q --filter=blob:none "${forkURL}" \
    "+refs/heads/main:refs/remotes/fork/main" "+refs/heads/development:refs/remotes/fork/development" || true

for branch in "${BRANCHES[@]}"; do
    upstreamSHA="$( git -C "${workDir}" rev-parse "refs/remotes/upstream/${branch}" )"
    forkSHA="$( git -C "${workDir}" rev-parse -q --verify "refs/remotes/fork/${branch}" || true )"

    if [[ "${upstreamSHA}" == "${forkSHA}" ]]; then
        echo "${branch}: already in sync (${upstreamSHA:0:7})"
        continue
    fi

    pushArgs=()
    if [[ -n "${forkSHA}" ]] && ! git -C "${workDir}" merge-base --is-ancestor "${forkSHA}" "${upstreamSHA}"; then
        backupTag="backup/${branch}-$( date -u +%Y%m%d-%H%M%S )"
        echo "${branch}: can't fast-forward ${forkSHA:0:7} -> ${upstreamSHA:0:7}; saving ${backupTag} and resetting to upstream"
        if [[ "${DRY_RUN}" != "true" ]]; then
            git -C "${workDir}" push -q "${forkURL}" "${forkSHA}:refs/tags/${backupTag}"
        fi
        pushArgs+=(--force)
    else
        echo "${branch}: ${forkSHA:0:7} -> ${upstreamSHA:0:7}"
    fi

    if [[ "${DRY_RUN}" != "true" ]]; then
        git -C "${workDir}" push -q "${pushArgs[@]}" "${forkURL}" "${upstreamSHA}:refs/heads/${branch}"
    fi
done
