#!/usr/bin/env bash
# setup-mayanode.sh
# Interactive, Step-by-Step Mayanode Installation


###############################################################################
# 0. Early safety‑nets
###############################################################################
if [[ $EUID -eq 0 ]]; then
  echo "✗  Run this script as a regular user (with sudo), not as root."
  exit 1
fi
set -Eeuo pipefail
IFS=$'\n\t'

###############################################################################
# 1. Pretty printing & logging
###############################################################################
GREEN=$(tput setaf 2) ; RED=$(tput setaf 9) ; YELLOW=$(tput setaf 11) ; RESET=$(tput sgr0)
banner()  { printf "\n${YELLOW}==> %s${RESET}\n" "$*"; }
success() { printf   "${GREEN}✓ %s${RESET}\n"  "$*"; }
failure() { printf   "${RED}✗ %s${RESET}\n"  "$*"; }
prompt()  { local r; printf "${YELLOW}?${RESET} %s [y/N]: " "$*"; read -r r; [[ $r =~ ^[Yy]$ ]]; }

LOG_DIR="$HOME/mayanode-setup-logs"; mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/$(date +%Y%m%d-%H%M%S).log"
exec 9>>"$LOG_FILE"; export BASH_XTRACEFD=9; set -x
exec > >(tee -a "$LOG_FILE") 2>&1
trap 'set +x; exec 9>&-; exit' EXIT   # close FD 9 on exit

###############################################################################
# 2. Generic step runner
###############################################################################
run_step() {
  local name=$1; shift
  banner "$name"
  if prompt "Proceed with \"$name\"?"; then
    "$@" && success "$name completed" || { failure "$name failed – exiting."; exit 1; }
  else
    echo "Skipping \"$name\""
  fi
}

# ─────────────────────────── Step Functions ───────────────────────────────

# --------------------------------------------------------------------------
# install_packages
# • Installs all OS-level prerequisites via apt (compiler, proto, lz4, etc.)
# • Idempotent: safe to run multiple times
# • Exits non-zero on failure (run_step will catch it)
# --------------------------------------------------------------------------
install_packages() {
  sudo apt-get update -y
  sudo apt-get install -y \
       git make protobuf-compiler curl wget jq build-essential musl-tools \
       pv gawk linux-headers-generic ca-certificates gnupg lsb-release lz4 unzip
}

# --------------------------------------------------------------------------
# install_go
# • Interactively installs the Go tool-chain
# • Lets the user choose between distro package and official tarball
# • Verifies minimum version (>= 1.22) and checksum when using tarball
# • Leaves /usr/local/go ready and returns non-zero on failure
# • Not idempotent: overwrites any existing /usr/local/go
# --------------------------------------------------------------------------
install_go() {
  local wanted_ver="1.22.2"         # tarball version to fetch if chosen
  local min_ver="1.22"              # lowest acceptable version

  echo -e "\nChoose how to install Go:"
  select go_src in \
         "Ubuntu apt (whatever is current)" \
         "Official tarball ${wanted_ver}" ; do
    [[ -n $go_src ]] && break
  done

  # 1) Ubuntu repository
  if [[ $REPLY == 1 ]]; then
    banner "Installing Go from your distro repositories"
    sudo apt-get install -y golang-go

    if ! command -v go >/dev/null; then
      failure "go binary not found after apt install"; return 1
    fi
    local have
    have=$(go version | awk '{print $3}' | sed 's/^go//')
    if [[ $(printf '%s\n' "$min_ver" "$have" | sort -V | head -1) != "$min_ver" ]]; then
      failure "Ubuntu’s go ($have) is older than $min_ver"
      echo "Re‑run the installer and pick the tarball option instead."
      return 1
    fi
    success "Go ${have} installed via apt"
    return 0
  fi

  # 2) Official tarball (download & verify)
  banner "Installing Go ${wanted_ver} from official tarball"

  cd "$HOME" || { failure "cannot cd \$HOME"; return 1; }

  local base="https://dl.google.com/go"
  local tar="go${wanted_ver}.linux-amd64.tar.gz"
  local url="${base}/${tar}"
  local sum_url="${url}.sha256"

  echo "[→] Downloading tarball …"
  curl -# -O "${url}" || { failure "tarball download failed"; return 1; }

  echo "[→] Fetching checksum …"
  curl -s  -O "${sum_url}" \
        || { failure "checksum download failed"; rm -f "${tar}"; return 1; }

  echo "[→] Verifying …"
  if ! sha256sum -c <(echo "$(cat "${tar}.sha256")  ${tar}") ; then
    failure "Checksum mismatch"; rm -f "${tar}" "${tar}.sha256"; return 1;
  fi

  sudo rm -rf /usr/local/go
  sudo tar -C /usr/local -xzf "${tar}" \
        || { failure "tar extraction failed"; return 1; }

  rm -f "${tar}" "${tar}.sha256"
  success "Go ${wanted_ver} installed to /usr/local/go"
}

# --------------------------------------------------------------------------
# add_go_env
# • Persists GOROOT / GOPATH and patches PATH in ~/.bash_profile + ~/.bashrc
# • Replaces any previous block between markers, keeping the files tidy
# • Evaluates the new exports immediately so the current shell picks them up
# • Idempotent: rerunning replaces the existing block instead of duplicating it
# --------------------------------------------------------------------------
add_go_env() {
  local profile="$HOME/.bash_profile"
  local bashrc="$HOME/.bashrc"
  touch "$profile" "$bashrc"

  local start="# >>> MAYANODE-GO-ENV >>>"
  local end="# <<< MAYANODE-GO-ENV <<<"

  # Fresh content we want in both files
  read -r -d '' new_block <<'EOF'
# Go Tool-Chain
if [ -d /usr/local/go ]; then
  export GOROOT=/usr/local/go         # tarball install
elif [ -d /usr/lib/go ]; then
  export GOROOT=/usr/lib/go           # distro install
fi

export GOPATH=$HOME/go
export GO111MODULE=on

case ":$PATH:" in
  *:$GOROOT/bin:*) ;;                 # already present
  *) [ -d "$GOROOT/bin" ] && PATH=$GOROOT/bin:$HOME/go/bin:$PATH ;;
esac
export PATH
EOF

  # function to (re)write one shell start‑up file
  update_file() {
    local file=$1
    if grep -qF "$start" "$file"; then
      # delete everything between the markers first
      sed -i "/$start/,/$end/d" "$file"
    fi
    printf "%s\n%s\n%s\n" "$start" "$new_block" "$end" >>"$file"
  }

  update_file "$profile"
  update_file "$bashrc"

  # Apply to current process
  eval "$new_block"
}

# --------------------------------------------------------------------------
# add_mayanode_env
# • Writes MAYANODE-specific environment variables (e.g. MAYANODE_NODE) to
#     ~/.bash_profile and ~/.bashrc between unique markers
# • Idempotent: rerunning replaces the existing block rather than duplicating it
# • Immediately evals the block so the current shell inherits the variables
# --------------------------------------------------------------------------
add_mayanode_env() {
  local profile="$HOME/.bash_profile"
  local bashrc="$HOME/.bashrc"
  touch "$profile" "$bashrc"

  local marker="# >>> MAYANODE-ENV >>>"
  read -r -d '' env_block <<'EOF'
# ── Mayanode environment variables ─────────────────────────────────────────
# MAYANODE_NODE for the Tendermint RPC endpoint
export MAYANODE_NODE="tcp://localhost:27147"
EOF

  # Persist to both startup files (only once, via the marker)
  for f in "$profile" "$bashrc"; do
    grep -qF "$marker" "$f" || {
      printf '%s\n%s\n# <<< MAYANODE-ENV <<<' "$marker" "$env_block" >>"$f"
    }
  done

  # Make the variables live for the remainder of this install run
  eval "$env_block"
}

# --------------------------------------------------------------------------
# install_docker
# • Adds Docker’s official APT repository and GPG key, then installs
#     docker-ce, CLI, containerd, Buildx, and Compose
# • Idempotent: re-running simply confirms the packages are present/up-to-date
# • Returns non-zero on any network, key-import, or apt failure
# --------------------------------------------------------------------------
install_docker() {
  sudo mkdir -p /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg |
      sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
    https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" |
      sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
  sudo apt-get update -y
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io \
       docker-buildx-plugin docker-compose-plugin
}

# --------------------------------------------------------------------------
# install_aws_cli
# • Installs AWS CLI v2 from the official ZIP when the `aws` binary is absent
# • Idempotent: skips download and install when AWS CLI is already in PATH
# • Returns non-zero on any network, unzip, or installer failure
# --------------------------------------------------------------------------
install_aws_cli() {
  if ! command -v aws >/dev/null; then
    curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o awscliv2.zip
    unzip -q awscliv2.zip
    sudo ./aws/install
    rm -rf aws awscliv2.zip
  fi
}

# --------------------------------------------------------------------------
# install_mayanode
# • Clones the mayanode Git repository (skips if already present)
# • Prompts the user to pick a tag/branch, checks it out, and optionally runs
#     `make protob` to generate protobuf files
# • Idempotent: if $HOME/mayanode/.git exists it simply returns success
# --------------------------------------------------------------------------
install_mayanode() {
  # Skip clone & checkout when the repository already exists
  if [ -d "$HOME/mayanode/.git" ]; then
    echo "[i] $HOME/mayanode already exists – skipping clone/build."
    return 0            # success → the wrapper moves on to the next step
  fi

  # Clone + checkout tag/branch chosen interactively
  git clone https://gitlab.com/mayachain/mayanode.git || {
    failure "Git clone failed"; return 1; }
  cd mayanode
  git fetch --tags --quiet
  git fetch origin develop --quiet
  # Read tags into an array without word-splitting
  mapfile -t _tags < <(git tag)
  local options=(develop "${_tags[@]}")
  echo "Available branches/tags:"
  for i in "${!options[@]}"; do printf "%2s) %s\n" "$i" "${options[$i]}"; done
  read -rp "Enter number to check out: " sel
  if ! [[ "$sel" =~ ^[0-9]+$ ]] || (( sel >= ${#options[@]} )); then
    failure "Invalid selection"
    return 1
  fi

  git checkout -q "${options[$sel]}"

  if prompt "Build mayanode with 'make protob'?"; then
    make protob
  fi
}


###############################################################################
# Helpers for the external P2P address
###############################################################################
get_external_addr() {
  local a
  while true; do
    read -rp "Public P2P address to advertise (host:port) [blank = none]: " a
    [[ -z $a ]] && { echo ""; return; }
    # host / IPv4 / [IPv6]  plus colon & port 1‑65535
    if [[ $a =~ ^([a-zA-Z0-9.-]+|\[[0-9a-fA-F:]+\]):([1-9][0-9]{0,4})$ \
          && ${BASH_REMATCH[2]} -le 65535 ]]; then
      echo "$a"; return
    fi
    echo "✗  Invalid. Examples:  node.example.com:27146   or   203.0.113.7:27146"
  done
}


set_external_addr() {                 # ← **ONLY CHANGED FUNCTION**
  local addr=$1 cfg="$HOME/.mayanode/config/config.toml"
  [[ -z $addr ]] && return 0          # nothing to do

  mkdir -p "$(dirname "$cfg")"
  if grep -Eq '^[[:space:]]*#?[[:space:]]*external_address[[:space:]]*=' "$cfg" 2>/dev/null; then
    # replace (also works if the line is commented out or indented)
    sed -Ei 's|^[[:space:]]*#?[[:space:]]*external_address[[:space:]]*=.*|external_address = "'"$addr"'"|' "$cfg"
  else
    # append cleanly at EOF
    printf '\nexternal_address = "%s"\n' "$addr" >>"$cfg"
  fi
}

ensure_configs() {               # $1 = addr
  local cfg="$HOME/.mayanode/config/config.toml"
  [[ -f $cfg ]] || /usr/local/bin/mayanode render-config
  set_external_addr "$1"
}

# --------------------------------------------------------------------------
# create_service
# • (Re)writes /etc/systemd/system/mayanode.service so that, on every start,
#   it patches ~/.mayanode/config/config.toml to contain the user‑supplied
#   external_address.  The heavy‑weight `render-config` is still executed
#   only on the first boot when no config exists.
# --------------------------------------------------------------------------

create_service() {                          # $1 = addr (may be blank)
  local addr="$1"
  local svc="/etc/systemd/system/mayanode.service"
  local user="${SUDO_USER:-$(whoami)}"
  local home="/home/${user}"
  local flag=""; [[ -n $addr ]] && flag=" --external_address=${addr}"

  # ── ExecStartPre #1 ──────────────────────────────────────────────────────
  # Generate default config *only once*, in the right place.
  local exec_pre1="/usr/bin/bash -c '[ -f \"${home}/.mayanode/config/config.toml\" ] || \
/usr/local/bin/mayanode render-config --home \"${home}/.mayanode\"${flag}'"

  # ── ExecStartPre #2 ──────────────────────────────────────────────────────
  # Ensure/refresh the external_address inside config.toml every restart.
  local exec_pre2="/usr/bin/bash -c 'cfg=\"${home}/.mayanode/config/config.toml\"; \
grep -q \"^[[:space:]]*external_address[[:space:]]*=.*${addr}\" \"\$cfg\" && exit 0; \
if grep -q \"^[[:space:]]*external_address[[:space:]]*=\" \"\$cfg\"; then \
  sed -Ei \"s|^[[:space:]]*external_address[[:space:]]*=.*|external_address = \\\"${addr}\\\"|\" \"\$cfg\"; \
else \
  echo \"external_address = \\\"${addr}\\\"\" >> \"\$cfg\"; \
fi'"

  # ── Rewrite the unit only if necessary ──────────────────────────────────
  if [[ -f $svc ]] && grep -qF "ExecStartPre=${exec_pre1}" "$svc" \
                   && grep -qF "ExecStartPre=${exec_pre2}" "$svc"; then
    echo "[i] systemd unit already up‑to‑date – skipping."
    return 0
  fi
  echo "[i] (Re)writing systemd unit with correct ExecStartPre commands."

  cat <<EOF | sudo tee "$svc" >/dev/null
[Unit]
Description=Mayanode
After=network-online.target
Wants=network-online.target

[Service]
User=${user}
WorkingDirectory=${home}/mayanode
ExecStartPre=${exec_pre1}
ExecStartPre=${exec_pre2}
ExecStart=/usr/local/bin/mayanode start --home ${home}/.mayanode
Restart=always
RestartSec=3
LimitNOFILE=4096
Environment="MAYA_COSMOS_TELEMETRY_ENABLED=true"
Environment="CHAIN_ID=mayachain-mainnet-v1"
Environment="NET=mainnet"

[Install]
WantedBy=multi-user.target
EOF

  success "systemd unit written/updated"
}

# --------------------------------------------------------------------------
# install_binary
# • Runs `make install` (TAG=mainnet NET=mainnet) to build & install mayanode
#     into $HOME/go/bin
# • Copies the binary to /usr/local/bin (sudo) so every user and future shell
#     can invoke `mayanode`; refreshes the shell’s hash table (hash -r)
# • Idempotent: re-running overwrites the same /usr/local/bin/mayanode
#     with the identical binary, causing no side-effects
# --------------------------------------------------------------------------
install_binary() {
  cd "$HOME/mayanode"
  TAG=mainnet NET=mainnet make install

  # Always expose the CLI system-wide
  sudo install -m 0755 "$HOME/go/bin/mayanode" /usr/local/bin/mayanode

  # Forget any old PATH look-ups so the new binary is found immediately
  hash -r            # <-- added

  echo "[i] Installed mayanode → /usr/local/bin/mayanode"
}

# --------------------------------------------------------------------------
# configure_shared_libs
# • Registers $HOME/mayanode/lib in /etc/ld.so.conf.d and runs ldconfig so the
#     dynamic linker can find mayanode’s shared libraries system-wide
# • Idempotent: overwrites the same /etc/ld.so.conf.d/mayanode.conf on each run
# • Returns non-zero if it cannot write the conf file or ldconfig fails
# --------------------------------------------------------------------------
configure_shared_libs() {
  local libdir="$HOME/mayanode/lib"

  # create conf atomically & idempotently
  echo "$libdir" | sudo tee /etc/ld.so.conf.d/mayanode.conf >/dev/null
  sudo ldconfig
}

# --------------------------------------------------------------------------
# fetch_snapshot
# • Downloads the latest pruned or full blockchain snapshot from S3, verifies
#     free disk space, and (optionally) extracts it, swapping the node database
# • Stops mayanode before extraction and restarts it afterward if it was
#     previously running; makes a timestamped backup of any existing DB
# --------------------------------------------------------------------------
fetch_snapshot() {
  set -e
  local SNAP_BUCKET="public-snapshots-mayanode"
  local SNAP_CLASS height snap_url
  local workdir="$HOME/.mayanode"        # root of all Maya data
  local dbdir="$workdir/data"            # current database
  mkdir -p "$dbdir"

  # 1) Snapshot flavour
  echo -e "\nChoose snapshot type:"
  PS3=$'[?] Snapshot type → '
  select SNAP_CLASS in pruned full; do [[ -n $SNAP_CLASS ]] && break; done
  [[ $SNAP_CLASS == full ]] \
        && echo -e "\n[i] Full snapshots ≈ 750 GB." \
        || echo -e "\n[i] Pruned snapshots ≈ 200 GB."

  # 2) Latest height
  prompt "Look up the latest snapshot height now?" || { echo "Skipped."; return 0; }
  echo "[+] Querying bucket …"
  height=$(aws s3 ls "s3://${SNAP_BUCKET}/${SNAP_CLASS}/" --no-sign-request |
           awk '{print $2}' | tr -d '/' | sort -n | tail -1)
  [[ -n $height ]] || { failure "Could not determine snapshot height"; return 1; }
  prompt "Latest snapshot is ${height}. Continue?" || { echo "Aborted."; return 1; }

  # 3) Free‑space guard
  local required_gb free_gb
  if [[ $SNAP_CLASS == full ]]; then required_gb=800; else required_gb=250; fi
  free_gb=$(df -BG "$workdir" | awk 'NR==2 {print int($4)}')
  (( free_gb >= required_gb )) || {
       failure "Only ${free_gb} GB free; need ${required_gb} GB."; return 1; }

  # 4) Download tarball
  snap_url="s3://${SNAP_BUCKET}/${SNAP_CLASS}/${height}/${height}.tar.gz"
  local tmp_tar="$workdir/${height}.tar.gz.partial"
  local final_tar="$workdir/${height}.tar.gz"
  echo "[→] Downloading snapshot …"
  aws s3 cp "$snap_url" "$tmp_tar" --no-sign-request
  mv "$tmp_tar" "$final_tar"
  echo "[✓] Download complete → ${final_tar}"

  # 5) Ask whether to proceed with extraction NOW or postpone
  if ! prompt "Extract & apply the snapshot now? (node will be stopped)"; then
      echo "[i] Extraction postponed.  Keep ${final_tar} and run this function later."
      return 0
  fi

  # 6) Stop running service
  local running=false
  if systemctl is-active --quiet mayanode; then
    running=true
    echo "[i] Stopping mayanode for safe extraction …"
    sudo systemctl stop mayanode
  fi

  # 7) Decide strip depth (1 or 2) by peeking into the tarball
  local strip_depth
  if tar tzf "$final_tar" | head -1 | grep -qE '^[0-9]+/data/'; then
      strip_depth=2          # <height>/data/…
  else
      strip_depth=1          # data/…
  fi

  # 8) Extract into fresh dir
  local newdir="$workdir/data.new"
  rm -rf "$newdir" && mkdir -p "$newdir"
  echo "[→] Extracting with --strip-components=${strip_depth} …"
  if command -v pv >/dev/null; then
      pv -f "$final_tar" | tar xzf - -C "$newdir" --strip-components="$strip_depth"
  else
      tar xzf "$final_tar" -C "$newdir" --strip-components="$strip_depth"
  fi
  [[ -d "$newdir/application.db" ]] || {
        failure "Extraction incomplete"; rm -rf "$newdir";
        $running && sudo systemctl start mayanode; return 1; }

  # 9) Swap database; backup only if an old DB exists
  local timestamp; timestamp=$(date +%Y%m%d-%H%M%S)
  if [[ -d "$dbdir/application.db" ]]; then
      mv "$dbdir" "${dbdir}.backup-${timestamp}"
      echo "[i] Existing DB moved to ${dbdir}.backup-${timestamp}"
  else
      rm -rf "$dbdir"
  fi
  mv "$newdir" "$dbdir"
  echo "[✓] Snapshot in place."

  $running && { echo "[i] Restarting mayanode"; sudo systemctl start mayanode; }

  # 10) Optional cleanup
  prompt "Delete downloaded tarball to save space?" && rm -f "$final_tar"

  success "Snapshot restore finished"
}

# --------------------------------------------------------------------------
# setup_ufw
# • Installs and configures UFW: default deny-in / allow-out, plus rules for
#     SSH, MAYAChain P2P (27146), Tendermint RPC (27147), and optional REST 1317
# • Idempotent: re-runs `ufw reset`, then re-applies rules based on prompts
# • Returns non-zero only if UFW or apt operations fail
# --------------------------------------------------------------------------
setup_ufw() {
  if ! dpkg -s ufw >/dev/null 2>&1; then
    sudo apt-get update -y && sudo apt-get install -y ufw
  fi

  echo "This step will:"
  echo " • Set default: deny incoming / allow outgoing"
  echo " • Allow SSH (22/tcp)"
  echo " • Allow MAYAChain P2P (27146/tcp)"
  echo " • Allow Tendermint RPC (27147/tcp) from a host *you* choose"
  echo " • Optionally allow REST (1317/tcp)"
  echo " • Enable UFW"

  # Extra prompt so users don’t lock themselves out
  if ! prompt "Continue configuring UFW?"; then
    echo "UFW setup skipped"
    return 0
  fi
  # safe reset
  if ! sudo ufw status | grep -q "Status: active"; then
    sudo ufw --force reset
  fi
  sudo ufw default deny incoming
  sudo ufw default allow outgoing
  sudo ufw allow 22/tcp   comment 'SSH'

  sudo ufw allow 27146/tcp comment 'MAYAChain P2P'

  # Ask which IP should reach Tendermint RPC
  read -rp "Enter host/CIDR for RPC 27147 (blank = skip): " rpc_ip
  if [[ -z "$rpc_ip" ]]; then
    echo "[i] RPC remains closed."
  elif [[ "$rpc_ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}(/[0-9]{1,2})?$ ]]; then
    sudo ufw allow from "$rpc_ip" to any port 27147 proto tcp comment 'Tendermint RPC'
    echo "[✓] UFW rule added for $rpc_ip → 27147"
  else
    echo "[i] Invalid address – RPC remains closed."
  fi
  # Optional REST API – ask which host (if any) may reach it
  if prompt "Add REST API rule (1317/tcp)?"; then
    read -rp "  Enter host/CIDR allowed for 1317 (blank = skip): " rest_ip
    if [[ "$rest_ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}(/[0-9]{1,2})?$ ]]; then
      sudo ufw allow from "$rest_ip" to any port 1317 proto tcp comment 'Cosmos REST'
      echo "[✓] UFW rule added for $rest_ip → 1317"
    else
      echo "[i] No valid address entered – REST API remains closed."
    fi
  fi


  sudo ufw --force enable
  sudo ufw status verbose
}

# --------------------------------------------------------------------------
# enable_service
# • Reloads systemd daemon, enables the mayanode service, and starts it
#     immediately (`systemctl enable --now`)
# • Prints concise status output; returns non-zero if systemctl commands fail
# • Idempotent: subsequent runs leave the service enabled and simply restart it
# --------------------------------------------------------------------------
enable_service() {
  sudo systemctl daemon-reload
  sudo systemctl enable --now mayanode.service
  sudo systemctl status --no-pager mayanode
}

# ───────────────────────── Main Execution Flow ────────────────────────────
main() {
  banner "Interactive Mayanode setup script"

  run_step "Install required apt packages"      install_packages
  run_step "Install Go"                         install_go
  run_step "Add Go env vars"                    add_go_env
  run_step "Add Mayanode env vars"              add_mayanode_env
  run_step "Install Docker & Compose"           install_docker
  run_step "Install AWS CLI"                    install_aws_cli
  run_step "Clone / build Mayanode"             install_mayanode
  run_step "Install Mayanode binary"            install_binary

  EXT_ADDR=$(get_external_addr)
  run_step "Ensure configs"              	ensure_configs "$EXT_ADDR"
  run_step "Create systemd service"      	create_service "$EXT_ADDR"

  run_step "Configure shared libraries"         configure_shared_libs
  run_step "Fetch & extract latest snapshot"    fetch_snapshot
  run_step "Configure UFW firewall"             setup_ufw
  run_step "Enable & start Mayanode service"    enable_service

  banner "All done!"
  echo "Please reboot or run 'source ~/.bash_profile && source ~/.bashrc' to apply the environment changes."
  echo "Use sudo journalctl -feu mayanode to follow logs."

}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  # Ensure environment is set without sourcing potentially problematic files
  export PATH="$PATH:$HOME/go/bin:/usr/local/bin"
  export MAYANODE_NODE="tcp://localhost:27147"
fi

# ────────────────────────── Cleanup On Exit ──────────────────────────────
cleanup() {
  set +x           # stop x-trace so nothing else writes to FD 9
  exec 9>&-        # close FD 9 → flushes & releases $LOG_FILE handle
}
trap cleanup EXIT

main "$@"
