#!/usr/bin/env bash
set -euo pipefail

# Only the disposable Linux Actions runner may change its package transport.
[[ "${GITHUB_ACTIONS:-}" == true && "${RUNNER_OS:-}" == Linux ]]
case "${1:-}" in chromium|firefox|webkit) browser=$1 ;; *) exit 2 ;; esac

config=/etc/apt/apt.conf.d/99-hoopito-ci-network
mirrors=/etc/apt/apt-mirrors.txt
backup=$(mktemp)
config_created=false
mirrors_changed=false
cleanup() {
  if $mirrors_changed; then sudo cp -- "$backup" "$mirrors"; fi
  if $config_created; then sudo rm -- "$config"; fi
  rm -- "$backup"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# Never replace a configuration owned by another setup step.
[[ ! -e "$config" ]]
config_created=true
printf '%s\n' 'Acquire::http::Timeout "30";' \
  'Acquire::https::Timeout "30";' 'Acquire::Retries "2";' |
  sudo tee "$config" >/dev/null
if [[ -f "$mirrors" ]]; then
  cp -- "$mirrors" "$backup"
  mirrors_changed=true
  # Keep the official archive, signatures and all other mirror entries intact.
  # The Azure HTTP endpoint stalled for 13–16 minutes in the preserved run.
  sed 's#https\?://azure.archive.ubuntu.com/ubuntu#https://archive.ubuntu.com/ubuntu#g' \
    "$backup" | sudo tee "$mirrors" >/dev/null
fi
npx playwright install --with-deps --no-shell "$browser"
