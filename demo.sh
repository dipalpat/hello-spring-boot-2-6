#!/usr/bin/env bash
# Demo of the advisor upgrade flow, driven by demo-magic.sh
# https://github.com/paxtonhare/demo-magic
#
# Usage: ./demo.sh [-n]      (-n = no simulated typing)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- fetch demo-magic.sh next to this script if missing ---------------------
DM="$SCRIPT_DIR/demo-magic.sh"
if [ ! -f "$DM" ]; then
  curl -fsSL -o "$DM" \
    https://raw.githubusercontent.com/paxtonhare/demo-magic/master/demo-magic.sh
fi
# shellcheck disable=SC1090
. "$DM"

# --- demo-magic settings -----------------------------------------------------
TYPE_SPEED=30
DEMO_PROMPT="${GREEN}➜ ${CYAN}\W ${COLOR_RESET}"
# DEMO_CMD_COLOR=$BLACK   # uncomment for light terminals

# Make `sdk` available in this non-interactive shell
export SDKMAN_DIR="${SDKMAN_DIR:-$HOME/.sdkman}"
# shellcheck disable=SC1091
[ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ] && . "$SDKMAN_DIR/bin/sdkman-init.sh"

# Work in a throwaway directory so the demo never touches your real checkout
DEMO_DIR="$(mktemp -d)"
trap 'rm -rf "$DEMO_DIR"' EXIT
cd "$DEMO_DIR" || exit 1

clear

# --- helper: run a step, pausing for the presenter ---------------------------
step() { # step "comment" command...
  p "# $1"
  shift
  pe "$*"
  wait
}

# --- the demo ----------------------------------------------------------------
step "Clone the sample Spring Boot 2.6 app" \
  "git clone git@github.com:dipalpat/hello-spring-boot-2-6.git"

pe "cd hello-spring-boot-2-6"

# Hidden setup (not typed on screen): do all work on a throwaway branch so
# `--push` never touches main. Delete it afterwards with:
#   git push origin --delete "$DEMO_BRANCH"
DEMO_BRANCH="demo/advisor-$(date +%Y%m%d-%H%M%S)"
git checkout -q -b "$DEMO_BRANCH"
git config push.autoSetupRemote true
# advisor's --push/PR flow looks up the current branch on GitHub, so it must exist remotely
git push -q -u origin "$DEMO_BRANCH"
gh repo set-default dipalpat/hello-spring-boot-2-6   # fresh clone has no gh default repo
echo "(demo branch: $DEMO_BRANCH)" >&2
# `sdk use java` with no version prompts interactively; `sdk env install` reads .sdkmanrc and installs the JDK if missing
step "Install and select the project's Java version" "sdk env install"

step "Publish the build config" "advisor build-config publish"
step "Show the upgrade plan"    "advisor upgrade-plan get"
step "Apply the first 3 steps, squashed" \
  "advisor upgrade-plan apply --squash 3 --push"
step "Merge the PR on GitHub, then continue" \
  "gh pr merge ${DEMO_BRANCH}-upgrade-plan --merge --delete-branch"
pe "git fetch -q && git reset -q --hard origin/${DEMO_BRANCH}"
step "Re-publish the build config" "advisor build-config publish"

step "Apply available patches and push" "advisor patch apply --push"
step "Merge the PR on GitHub, then continue" \
  "gh pr merge ${DEMO_BRANCH}-patch-upgrade --merge --delete-branch"
pe "git fetch -q && git reset -q --hard origin/${DEMO_BRANCH}"
step "Show the remaining upgrade plan" "advisor upgrade-plan get"
step "Apply the next 6 steps, squashed, and push" \
  "advisor upgrade-plan apply --squash 6 --push"
step "Merge the PR on GitHub, then continue" \
  "gh pr merge ${DEMO_BRANCH}-upgrade-plan --merge --delete-branch"
pe "git fetch -q && git reset -q --hard origin/${DEMO_BRANCH}"
step "Final build config publish" "advisor build-config publish"

step "Clean up the demo branch" "git push origin --delete ${DEMO_BRANCH}"

p "# Done!"
