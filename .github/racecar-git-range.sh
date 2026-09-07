#!/usr/bin/env bash
# racecar: make `bioconda-utils --git-range` usable on a fork and on a
# workflow_dispatch. Sourced (not executed) so RACECAR_GIT_BASE is exported to
# the caller. Two things upstream's PR.yml can take for granted and we cannot:
#
# 1. bioconda_utils' GitHandler resolves its "home" repository by matching the
#    literal string 'bioconda/bioconda-recipes' against the remote URLs
#    (bioconda_utils/githandler.py, GitHandlerBase.__init__ -> get_remote).
#    On a fork `origin` points at curiosity-tests/bioconda-recipes, so every
#    --git-range invocation dies with
#      KeyError: "No remote matching 'bioconda/bioconda-recipes' found"
#    Adding the upstream URL as an extra remote is enough - get_remote only
#    reads remote URLs from config, it never fetches.
#
# 2. GITHUB_BASE_REF is only populated for pull_request events, so on the
#    dispatched racecar legs `origin/"$GITHUB_BASE_REF"` expands to the
#    unresolvable ref `origin/`. (fulcrumgenomics/fetch-through-merge-base does
#    set GITHUB_BASE_REF, but only inside its own step: its
#    `export GITHUB_BASE_REF="..." >> $GITHUB_ENV` redirects export's empty
#    stdout instead of writing to the env file, so nothing reaches later steps.)

if ! git remote get-url racecar-upstream >/dev/null 2>&1; then
  git remote add racecar-upstream https://github.com/bioconda/bioconda-recipes.git
  # Nothing in `lint`/`build` writes to a remote, but actions/checkout installs
  # its GITHUB_TOKEN extraheader for every github.com URL in this repo, so make
  # the remote structurally read-only rather than relying on that token having
  # no write scope upstream.
  git remote set-url --push racecar-upstream no-push.invalid/bioconda/bioconda-recipes
fi

if [ -n "${GITHUB_BASE_REF:-}" ] && git rev-parse --verify --quiet "origin/${GITHUB_BASE_REF}" >/dev/null; then
  RACECAR_GIT_BASE="origin/${GITHUB_BASE_REF}"
elif git rev-parse --verify --quiet "origin/${GITHUB_REF_NAME:-master}" >/dev/null; then
  RACECAR_GIT_BASE="origin/${GITHUB_REF_NAME:-master}"
else
  RACECAR_GIT_BASE="$(git rev-parse HEAD)"
fi
export RACECAR_GIT_BASE
echo "racecar: --git-range base is ${RACECAR_GIT_BASE} ($(git rev-parse "${RACECAR_GIT_BASE}"))"
