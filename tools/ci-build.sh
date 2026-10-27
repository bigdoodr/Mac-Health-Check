#!/usr/bin/env bash
#
# Find upstream Mac Health Check versions that don't have a WKU build yet, build them, and publish
# each as a prerelease on this fork. Problems become GitHub issues labeled "wku-build".
#
# What gets built (unless a ref is passed):
#   - upstream's latest stable release
#   - upstream's newest release of any kind (betas / release candidates)
#   - the head of upstream's development branch, when it differs from both of the above
#
# A build is identified by the upstream version plus the WKU overlay hash, so a change to wku/ or
# tools/ automatically produces fresh builds of the same upstream versions.
#
# Usage:
#   tools/ci-build.sh                   detect and build what's new
#   tools/ci-build.sh v5.0.1            build one upstream tag
#   tools/ci-build.sh development       build one upstream branch head
#   FORCE=true tools/ci-build.sh ...    rebuild even if the release already exists
#   DRY_RUN=true tools/ci-build.sh      build into ./work but publish nothing
#
# Needs: gh (authenticated via GH_TOKEN), git, python3, zsh.

set -euo pipefail

UPSTREAM_REPO="dan-snelson/Mac-Health-Check"
UPSTREAM_URL="https://github.com/${UPSTREAM_REPO}.git"
FORK_REPO="${GITHUB_REPOSITORY:-bigdoodr/Mac-Health-Check}"
FORCE="${FORCE:-false}"
DRY_RUN="${DRY_RUN:-false}"
KEEP_DEV_BUILDS="${KEEP_DEV_BUILDS:-5}"
ISSUE_LABEL="wku-build"

repoRoot="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
cd "${repoRoot}"
workRoot="${repoRoot}/work"
upstreamGit="${workRoot}/upstream.git"
mkdir -p "${workRoot}"
[[ -d "${upstreamGit}" ]] || git init -q --bare "${upstreamGit}"

overlaySHA="$( python3 -c 'import sys; sys.path.insert(0, "tools"); import build; print(build.overlay_sha())' )"
overlayCommit="${GITHUB_SHA:-$( git rev-parse HEAD )}"
echo "WKU overlay ${overlaySHA} (commit ${overlayCommit:0:7})"

failures=0
summary=()

# -----------------------------------------------------------------------------------------------

function upstreamFetch() {  # <refspec>  -> prints commit SHA
    git -C "${upstreamGit}" fetch -q --depth 1 "${UPSTREAM_URL}" "${1}"
    git -C "${upstreamGit}" rev-parse "FETCH_HEAD^{commit}"
}

function openOrUpdateIssue() {  # <title> <body-file>
    local title="${1}" bodyFile="${2}" number
    if [[ "${DRY_RUN}" == "true" ]]; then
        echo "DRY RUN: would open/update issue: ${title}"; return
    fi
    gh label create "${ISSUE_LABEL}" -R "${FORK_REPO}" --color B01E24 \
        --description "WKU Mac Health Check build needs attention" >/dev/null 2>&1 || true
    number="$( gh issue list -R "${FORK_REPO}" --label "${ISSUE_LABEL}" --state open --search "\"${title}\" in:title" \
        --json number,title --jq ".[] | select(.title == \"${title}\") | .number" | head -1 )"
    if [[ -n "${number}" ]]; then
        gh issue comment "${number}" -R "${FORK_REPO}" --body-file "${bodyFile}" >/dev/null
        echo "Updated issue #${number}: ${title}"
    else
        gh issue create -R "${FORK_REPO}" --title "${title}" --label "${ISSUE_LABEL}" --body-file "${bodyFile}" >/dev/null
        echo "Opened issue: ${title}"
    fi
}

function closeIssue() {  # <title>
    local title="${1}" number
    [[ "${DRY_RUN}" == "true" ]] && return
    number="$( gh issue list -R "${FORK_REPO}" --label "${ISSUE_LABEL}" --state open --search "\"${title}\" in:title" \
        --json number,title --jq ".[] | select(.title == \"${title}\") | .number" | head -1 )"
    if [[ -n "${number}" ]]; then
        gh issue close "${number}" -R "${FORK_REPO}" --comment "Fixed: ${2}" >/dev/null
        echo "Closed issue #${number}"
    fi
}

function changelogSection() {  # <commit> <version>
    git -C "${upstreamGit}" show "${1}:CHANGELOG.md" 2>/dev/null \
        | awk -v v="### ${2}" 'index($0, v) == 1 { on = 1; print; next } on && /^### / { exit } on { print }' \
        | head -150
}

# -----------------------------------------------------------------------------------------------
# Decide what to build: lines of "<kind> <upstream ref>"

targets=()
if [[ -n "${1:-}" ]]; then
    if git ls-remote --exit-code --tags "${UPSTREAM_URL}" "refs/tags/${1}" >/dev/null 2>&1; then
        targets+=("tag ${1}")
    else
        targets+=("branch ${1}")
    fi
else
    latestStable="$( gh api "repos/${UPSTREAM_REPO}/releases/latest" --jq '.tag_name' 2>/dev/null || true )"
    newestAny="$( gh api "repos/${UPSTREAM_REPO}/releases?per_page=10" \
        --jq '[.[] | select(.draft | not)] | .[0].tag_name // empty' 2>/dev/null || true )"
    [[ -n "${latestStable}" ]] && targets+=("tag ${latestStable}")
    [[ -n "${newestAny}" && "${newestAny}" != "${latestStable}" ]] && targets+=("tag ${newestAny}")
    targets+=("branch development")
fi

builtCommits=" "

for target in "${targets[@]}"; do
    kind="${target%% *}"
    ref="${target#* }"
    title="WKU build needs attention: ${ref}"

    if [[ "${kind}" == "tag" ]]; then
        commit="$( upstreamFetch "+refs/tags/${ref}:refs/tags/${ref}" )"
    else
        commit="$( upstreamFetch "+refs/heads/${ref}:refs/remotes/upstream/${ref}" )"
    fi

    if [[ "${builtCommits}" == *" ${commit} "* ]]; then
        echo "${ref}: same commit as an earlier target (${commit:0:7}); skipping"
        continue
    fi
    builtCommits+="${commit} "

    buildDir="${workRoot}/${ref//\//-}"
    rm -rf "${buildDir}"; mkdir -p "${buildDir}"
    git -C "${upstreamGit}" show "${commit}:Mac-Health-Check.zsh" > "${buildDir}/upstream.zsh"
    version="$( sed -n 's/^scriptVersion="\([^"]*\)".*/\1/p' "${buildDir}/upstream.zsh" | head -1 )"

    if [[ "${kind}" == "tag" ]]; then
        releaseTag="${ref}-wku.${overlaySHA}"
        prereleaseNote="Upstream release [${ref}](https://github.com/${UPSTREAM_REPO}/releases/tag/${ref})"
    else
        releaseTag="dev-${version}-${commit:0:7}-wku.${overlaySHA}"
        prereleaseNote="Upstream \`${ref}\` branch at [${commit:0:7}](https://github.com/${UPSTREAM_REPO}/commit/${commit}) (unreleased)"
    fi

    if [[ "${overlaySHA}" == *-dirty || "${overlaySHA}" == local ]] && [[ "${DRY_RUN}" != "true" ]]; then
        echo "::error::Overlay has uncommitted changes (${overlaySHA}); commit them before publishing."
        exit 1
    fi

    if gh release view "${releaseTag}" -R "${FORK_REPO}" >/dev/null 2>&1; then
        if [[ "${FORCE}" != "true" ]]; then
            echo "${ref} (${version}): ${releaseTag} already published"
            summary+=("| ${ref} | ${version} | already built | \`${releaseTag}\` |")
            continue
        fi
        [[ "${DRY_RUN}" != "true" ]] && gh release delete "${releaseTag}" -R "${FORK_REPO}" --yes --cleanup-tag
    fi

    echo "::group::Build ${ref} (${version}, ${commit:0:7}) -> ${releaseTag}"
    set +e
    python3 tools/build.py --source "${buildDir}/upstream.zsh" --upstream-ref "${ref}" --upstream-sha "${commit}" \
        --out "${buildDir}/dist" --require-zsh > "${buildDir}/build.log" 2>&1
    rc=$?
    set -e
    cat "${buildDir}/build.log"
    echo "::endgroup::"

    if (( rc != 0 )); then
        failures=$(( failures + 1 ))
        reason="build error"; (( rc == 2 )) && reason="upstream changed a function WKU replaces"
        summary+=("| ${ref} | ${version} | **failed** (${reason}) | |")
        {
            echo "The WKU build of upstream **${ref}** (${version}, [${commit:0:7}](https://github.com/${UPSTREAM_REPO}/commit/${commit})) failed: ${reason}."
            echo
            if (( rc == 2 )); then
                echo "Upstream changed a function that \`wku/overrides.zsh\` replaces. Port the upstream change into the WKU version, then run \`python3 tools/build.py --source <upstream script> --update-baselines\` and commit both."
                echo
            fi
            echo "<details><summary>Build log</summary>"
            echo
            echo '```'
            tail -c 60000 "${buildDir}/build.log"
            echo '```'
            echo "</details>"
            echo
            [[ -n "${GITHUB_RUN_ID:-}" ]] && echo "Run: ${GITHUB_SERVER_URL:-https://github.com}/${FORK_REPO}/actions/runs/${GITHUB_RUN_ID}"
        } > "${buildDir}/issue.md"
        openOrUpdateIssue "${title}" "${buildDir}/issue.md"
        continue
    fi

    {
        echo "WKU build of Mac Health Check **${version}**. ${prereleaseNote}; WKU overlay \`${overlaySHA}\` ([wku@${overlayCommit:0:7}](https://github.com/${FORK_REPO}/tree/${overlayCommit}))."
        echo
        echo "| File | Use |"
        echo "|---|---|"
        echo "| \`WKU-MHC-SelfService.mosyle.sh\` | Paste into Mosyle custom command 3303 (MacHealthCheck4) |"
        echo "| \`WKU-MHC-Silent.mosyle.sh\` | Paste into Mosyle custom command 2530 (MacHealthCheck4 - Silent) |"
        echo "| \`WKU-MHC-*.zsh\` | Plain scripts, for reading or running by hand on a test Mac |"
        echo "| \`SHA256SUMS\`, \`build-info.json\` | Checksums and build details |"
        echo
        echo "Published as a **prerelease**. Test on the test device group first, then edit this release and untick \"Set as a pre-release\" once it's approved for the fleet."
        echo
        section="$( changelogSection "${commit}" "${version}" )"
        if [[ -n "${section}" ]]; then
            echo "<details><summary>Upstream changelog for ${version}</summary>"
            echo
            echo "${section}"
            echo
            echo "</details>"
        fi
    } > "${buildDir}/notes.md"

    if [[ "${DRY_RUN}" == "true" ]]; then
        echo "DRY RUN: would publish ${releaseTag} with $( cd "${buildDir}/dist" && printf '%s ' * )"
    else
        gh release create "${releaseTag}" -R "${FORK_REPO}" --target "${overlayCommit}" --prerelease \
            --title "WKU MHC ${version} (${kind} ${ref})" --notes-file "${buildDir}/notes.md" \
            "${buildDir}"/dist/*
        echo "Published ${releaseTag}"
    fi
    summary+=("| ${ref} | ${version} | built | \`${releaseTag}\` |")
    closeIssue "${title}" "${releaseTag} built successfully."
done

# Keep only the newest development builds; release builds are kept.
if [[ "${DRY_RUN}" != "true" ]]; then
    gh release list -R "${FORK_REPO}" --limit 200 --json tagName,createdAt \
        --jq '[.[] | select(.tagName | startswith("dev-"))] | sort_by(.createdAt) | reverse | .['"${KEEP_DEV_BUILDS}"':][] | .tagName' \
        | while read -r oldTag; do
            gh release delete "${oldTag}" -R "${FORK_REPO}" --yes --cleanup-tag && echo "Removed old development build ${oldTag}"
        done
fi

if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
    {
        echo "### WKU Mac Health Check builds (overlay \`${overlaySHA}\`)"
        echo
        echo "| Upstream | Version | Result | Release |"
        echo "|---|---|---|---|"
        printf '%s\n' "${summary[@]}"
    } >> "${GITHUB_STEP_SUMMARY}"
fi

(( failures == 0 ))
