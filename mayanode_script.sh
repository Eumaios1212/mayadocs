#!/usr/bin/env bash
# setup-mayanode.sh
# Interactive, step‑by‑step mayanode installation


# -----------------------------------------------------------------------------
# Abort if the script is run **as root**. Always invoke it as an unprivileged
# user who can sudo when prompted; otherwise $HOME resolves to /root and
# binaries & paths end up in the wrong place.
# -----------------------------------------------------------------------------
if [[ $EUID -eq 0 ]]; then
  echo "✗  Please run this script as a regular user who can sudo, not as root."
  echo "   e.g.  chmod +x setup-mayanode.sh && ./setup-mayanode.sh"
  exit 1
fi

set -Eeuo pipefail     # Fail fast on errors, undefined vars, or pipeline errors.

# -----------------------------------------------------------------------------
# Pretty-printing helpers — *must* come before we redirect stdout so that
# `tput` still talks to a real TTY and captures colour escape codes.
# -----------------------------------------------------------------------------
GREEN=$(tput setaf 2)
RED=$(tput setaf 9)
YELLOW=$(tput setaf 11)
RESET=$(tput sgr0)

# -----------------------------------------------------------------------------
# Quiet trace-logging:
#   • Full `set -x` output → file only (FD 9)
#   • Normal stdout/stderr → terminal *and* file (via tee)
# -----------------------------------------------------------------------------
LOG_DIR="$HOME/mayanode-setup-logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/$(date +%Y%m%d-%H%M%S).log"


# 1) open FD 9 to the log and route bash xtrace there
exec 9>>"$LOG_FILE"
export BASH_XTRACEFD=9
set -x            # tracing is active (file only)

# 2) duplicate regular output to both terminal and log
exec > >(tee -a "$LOG_FILE") 2>&1

# -----------------------------------------------------------------------------
# Misc early shell safety-nets
# -----------------------------------------------------------------------------
: "${LD_LIBRARY_PATH:=}"          # define as empty if it wasn’t set
IFS=$'\n\t'

###############################################################################
# Pretty-printing convenience functions
###############################################################################
banner()        { printf "\n${YELLOW}==> %s${RESET}\n" "$*"; }
success()       { printf "${GREEN}✓ %s${RESET}\n" "$*"; }
failure()       { printf "${RED}✗ %s${RESET}\n" "$*"; }
prompt() {
  local reply
  printf "${YELLOW}?${RESET} %s [y/N]: " "$*"
  read -r reply
  [[ "$reply" =~ ^[Yy]$ ]]
}

###############################################################################
# Utility for guarded execution of a *named* function
###############################################################################
run_step() {
  local step_name=$1; shift
  banner "$step_name"
  if prompt "Proceed with \"$step_name\"?"; then
    if "$@"; then
      success "$step_name completed"
    else
      failure "$step_name failed – exiting."
      exit 1
    fi
  else
    printf "Skipping \"%s\"\n" "$step_name"
  fi
}

###############################################################################
# Step functions
###############################################################################
install_packages() {
  sudo apt-get update -y
  sudo apt-get install -y \
       git make protobuf-compiler curl wget jq build-essential musl-tools \
       pv gawk linux-headers-generic ca-certificates gnupg lsb-release lz4 unzip
}

install_go() {
  local go_ver="1.22.2"                               # update when Maya supports a newer Go
  local tar="go${go_ver}.linux-amd64.tar.gz"
  local base="https://go.dev/dl"                    # For tarball
  local checksum_base="https://storage.googleapis.com/golang"  # For checksum

  # Skip when this exact version is already present
  if command -v go >/dev/null 2>&1 && go version | grep -q "go${go_ver}"; then
    echo "[i] Go ${go_ver} already installed – skipping."
    return 0
  fi

  cd "$HOME" || { failure "Cannot change to home directory"; return 1; }

  echo "[→] Downloading Go ${go_ver} …"
  if ! curl -fsSLO "${base}/${tar}" || [[ ! -f "$tar" ]]; then
    failure "Download failed"; return 1;
  fi

  echo "[→] Downloading checksum …"
  if ! curl -fsSLO "${checksum_base}/${tar}.sha256" || [[ ! -f "${tar}.sha256" ]]; then
    failure "Checksum file download failed"; rm -f "$tar"; return 1;
  fi

  # Validate checksum file content
  if [[ ! -s "${tar}.sha256" ]] || ! grep -qE '^[0-9a-f]{64}$' "${tar}.sha256"; then
    failure "Invalid checksum file content"; rm -f "$tar" "${tar}.sha256"; return 1;
  fi

  echo "[→] Verifying checksum …"
  checksum=$(tr -d '\n\r' < "${tar}.sha256")
  printf '%s  %s\n' "$checksum" "${tar}" | sha256sum -c - \
    || { failure "Checksum mismatch"; rm -f "$tar" "${tar}.sha256"; return 1; }

  echo "[→] Installing …"
  sudo rm -rf /usr/local/go
  sudo tar -C /usr/local -xzf "$tar" \
    || { failure "Extraction failed"; rm -f "$tar" "${tar}.sha256"; return 1; }

  rm -f "$tar" "${tar}.sha256"
  success "Go ${go_ver} installed successfully"
}

add_go_env() {
  local profile="$HOME/.bash_profile"
  local bashrc="$HOME/.bashrc"
  touch "$profile" "$bashrc"

  local marker="# >>> MAYANODE-GO-ENV >>>"
  read -r -d '' env_block <<'EOF'
export GOROOT=/usr/local/go
export GOPATH=$HOME/go
export GO111MODULE=on

# ── append Go paths only once ──
case ":$PATH:" in
  *:/usr/local/go/bin:*) ;;         # already present – do nothing
  *) PATH=$PATH:/usr/local/go/bin:$HOME/go/bin ;;
esac
export PATH

export LD_LIBRARY_PATH=${LD_LIBRARY_PATH:+$LD_LIBRARY_PATH:}$HOME/mayanode/lib
EOF

  # Persist to both startup files (only once, via the marker)
  for f in "$profile" "$bashrc"; do
    grep -qF "$marker" "$f" || {
      printf '%s\n%s\n# <<< MAYANODE-GO-ENV <<<' "$marker" "$env_block" >>"$f"
    }
  done

  # Make the variables live for the remainder of this install run
  eval "$env_block"

  : "${LD_LIBRARY_PATH:=}"   # protect strict-mode shells that might source later
}

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

install_aws_cli() {
  if ! command -v aws >/dev/null; then
    curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o awscliv2.zip
    unzip -q awscliv2.zip
    sudo ./aws/install
    rm -rf aws awscliv2.zip
  fi
}

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
  local options=(develop $(git tag))
  echo "Available branches/tags:"
  for i in "${!options[@]}"; do printf "%2s) %s\n" "$i" "${options[$i]}"; done
  read -rp "Enter number to check out: " sel
  [[ "$sel" =~ ^[0-9]+$ ]] && (( sel < ${#options[@]} )) || {
        failure "Invalid selection"; return 1; }
  git checkout -q "${options[$sel]}"

  if prompt "Build mayanode with 'make protob'?"; then
    make protob
  fi
}

create_service() {
  local svc_path="/etc/systemd/system/mayanode.service"
  # -----------------------------------------------------------------------
  # Skip creation when the unit file is already present
  # -----------------------------------------------------------------------
  if [ -f "$svc_path" ]; then
    echo "[i] $svc_path already exists – skipping service creation."
    return 0           # success → run_step proceeds to the next step
  fi

  local user="${SUDO_USER:-$(whoami)}"

  cat <<EOF | sudo tee "$svc_path" > /dev/null
[Unit]
Description=Mayanode
After=network-online.target

[Service]
User=${user}
WorkingDirectory=/home/${user}/mayanode
ExecStartPre=/home/${user}/go/bin/mayanode render-config
ExecStart=/home/${user}/go/bin/mayanode start
Restart=always
RestartSec=3
LimitNOFILE=4096
Environment="LD_LIBRARY_PATH=/home/${user}/mayanode/lib"
Environment="MAYA_COSMOS_TELEMETRY_ENABLED=true"
Environment="CHAIN_ID=mayachain-mainnet-v1"
Environment="NET=mainnet"
#Environment="SIGNER_NAME=mayachain"    # Only needed for validator nodes
#Environment="SIGNER_PASSWD=password"   # Only needed for validator nodes

[Install]
WantedBy=multi-user.target
EOF
}

install_binary() {
  cd "$HOME/mayanode"
  TAG=mainnet NET=mainnet make install

  # Always expose the CLI system-wide
  sudo install -m 0755 "$HOME/go/bin/mayanode" /usr/local/bin/mayanode

  # Forget any old PATH look-ups so the new binary is found immediately
  hash -r            # <-- added

  echo "[i] Installed mayanode → /usr/local/bin/mayanode"
}


fetch_snapshot() {
  set -e
  local SNAP_BUCKET="public-snapshots-mayanode"
  local SNAP_CLASS height snap_url
  local workdir="$HOME/.mayanode"        # root of all Maya data
  local dbdir="$workdir/data"            # current database
  mkdir -p "$dbdir"

  # ── 1. Snapshot flavour ────────────────────────────────────────────────
  echo -e "\nChoose snapshot type:"
  PS3=$'[?] Snapshot type → '
  select SNAP_CLASS in pruned full; do [[ -n $SNAP_CLASS ]] && break; done
  [[ $SNAP_CLASS == full ]] && echo -e "\n[i] Full snapshots ≈ 750 GB." \
                             || echo -e "\n[i] Pruned snapshots ≈ 200 GB."

  # ── 2. Latest height ───────────────────────────────────────────────────
  prompt "Look up the latest snapshot height now?" || { echo "Skipped."; return 0; }
  echo "[+] Querying bucket …"
  height=$(aws s3 ls "s3://${SNAP_BUCKET}/${SNAP_CLASS}/" --no-sign-request |
           awk '{print $2}' | tr -d '/' | sort -n | tail -1)
  [[ -n $height ]] || { failure "Could not determine snapshot height"; return 1; }
  prompt "Latest snapshot is ${height}. Continue?" || { echo "Aborted."; return 1; }

  # ── 2b. Free‑space guard ───────────────────────────────────────────────
  local required_gb free_gb
  if [[ $SNAP_CLASS == full ]]; then required_gb=800; else required_gb=250; fi
  free_gb=$(df -BG "$workdir" | awk 'NR==2 {print int($4)}')
  (( free_gb >= required_gb )) || {
     failure "Only ${free_gb} GB free; need ${required_gb} GB."; return 1; }

  # ── 3. Download (tarball saved in $workdir, NOT inside data/) ──────────
  snap_url="s3://${SNAP_BUCKET}/${SNAP_CLASS}/${height}/${height}.tar.gz"
  local tmp_tar="$workdir/${height}.tar.gz.partial"
  local final_tar="$workdir/${height}.tar.gz"
  echo "[→] Downloading snapshot …"
  aws s3 cp "$snap_url" "$tmp_tar" --no-sign-request
  mv "$tmp_tar" "$final_tar"
  echo "[✓] Download complete → ${final_tar}"

  # ── 4. Stop service only now ───────────────────────────────────────────
  local running=false
  if systemctl is-active --quiet mayanode; then
    running=true
    echo "[i] Stopping mayanode for safe extraction …"
    sudo systemctl stop mayanode
  fi

  # ── 5. Decide strip depth (1 or 2) by peeking into the tarball ─────────
  local strip_depth
  if tar tzf "$final_tar" | head -1 | grep -qE '^[0-9]+/data/'; then
    strip_depth=2          # <height>/data/…
  else
    strip_depth=1          # data/…
  fi

  # ── 6. Extract into fresh dir ──────────────────────────────────────────
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

  # ── 7. Swap database; backup only if an old DB exists ──────────────────
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

  # ── 8. Optional cleanup ────────────────────────────────────────────────
  prompt "Delete downloaded tarball to save space?" && rm -f "$final_tar"

  success "Snapshot restore finished"
}


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

enable_service() {
  sudo systemctl daemon-reload
  sudo systemctl enable --now mayanode.service
  sudo systemctl status --no-pager mayanode
}

###############################################################################
# Main execution flow
###############################################################################
main() {
  banner "Interactive Mayanode setup script"
  run_step "Install required apt packages"      install_packages
  run_step "Install Go"                         install_go
  run_step "Add Go env vars"                    add_go_env
  run_step "Install Docker & Compose"           install_docker
  run_step "Install AWS CLI"                    install_aws_cli
  run_step "Clone / build Mayanode"             install_mayanode
  run_step "Create systemd service"             create_service
  run_step "Install Mayanode binary"            install_binary
  run_step "Fetch & extract latest snapshot"    fetch_snapshot
  run_step "Configure UFW firewall"             setup_ufw
  run_step "Enable & start Mayanode service"    enable_service

  banner "All done!"
  echo "Use sudo journalctl -feu mayanode to follow logs."
  echo "Please reboot"
}

main "$@"
