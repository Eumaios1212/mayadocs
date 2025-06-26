#!/usr/bin/env bash
# setup-mayanode.sh
# Interactive, step‑by‑step mayanode installation

set -Eeuo pipefail     # Fail fast on errors, undefined vars, or pipeline errors.

# Pre-define LD_LIBRARY_PATH (empty) so 'set -u' won’t abort when it’s first expanded
: "${LD_LIBRARY_PATH:=}"   # define as empty if it wasn’t set
IFS=$'\n\t'

###############################################################################
# Pretty‑printing helpers
###############################################################################
GREEN=$(tput setaf 2)  RED=$(tput setaf 1)  YELLOW=$(tput setaf 3)  RESET=$(tput sgr0)

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
install_go() {
  local go_ver="1.22.2"  # Version that's been regression-tested
  cd "$HOME"
  sudo rm -rf /usr/local/go/
  wget -q "https://golang.org/dl/go${go_ver}.linux-amd64.tar.gz"
  sudo tar -C /usr/local -xzf "go${go_ver}.linux-amd64.tar.gz"
  rm "go${go_ver}.linux-amd64.tar.gz"
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



install_packages() {
  sudo apt-get update -y
  sudo apt-get install -y \
       git make protobuf-compiler curl wget jq build-essential musl-tools \
       pv gawk linux-headers-generic ca-certificates gnupg lsb-release lz4 unzip
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
  sudo ufw --force reset
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

install_mayanode() {
  # -----------------------------------------------------------------------
  # Skip clone & checkout when the repository already exists
  # -----------------------------------------------------------------------
  if [ -d "$HOME/mayanode/.git" ]; then
    echo "[i] $HOME/mayanode already exists – skipping clone/build."
    return 0            # success → the wrapper moves on to the next step
  fi

  # Clone + checkout tag/branch chosen interactively
  git clone https://gitlab.com/mayachain/mayanode || {
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
Environment="SIGNER_NAME=mayachain"
Environment="SIGNER_PASSWD=password"

[Install]
WantedBy=multi-user.target
EOF
}

install_binary() {
  cd "$HOME/mayanode"
  TAG=mainnet NET=mainnet make install

  # ensure 'mayanode' resolves in *every* shell without re-login
  if ! command -v mayanode >/dev/null 2>&1; then
    sudo ln -sf "$HOME/go/bin/mayanode" /usr/local/bin/mayanode
    echo "[i] Symlinked mayanode → /usr/local/bin/mayanode"
  fi
}

install_aws_cli() {
  if ! command -v aws >/dev/null; then
    curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o awscliv2.zip
    unzip -q awscliv2.zip
    sudo ./aws/install
    rm -rf aws awscliv2.zip
  fi
}

fetch_snapshot () {
  set -e                     # exit immediately on any error
  local SNAP_BUCKET="public-snapshots-mayanode"
  local SNAP_CLASS           # will be set via the select below

# Select full or pruned snapshot
  echo -e "\nChoose snapshot type:"
  PS3=$'[?] Snapshot type → '
  select SNAP_CLASS in pruned full; do
      [[ -n "$SNAP_CLASS" ]] && break
  done

  if [[ "$SNAP_CLASS" == "full" ]]; then
     echo -e "\n[i] ‘full’ snapshots are **very large** (≈ 750 GB)."
  else
     echo -e "\n[i] ‘pruned’ snapshots are slimmer (≈ 200 GB) – recommended for full nodes."
  fi

  mkdir -p "$HOME/.mayanode/data"

  # Snapshot lookup
  read -rp $'\n[?] Look up the latest snapshot height now? [y/N] ' ans
  [[ "$ans" =~ ^[Yy]$ ]] || { echo "Aborted."; return 1; }

  echo "[+] Fetching latest snapshot height from s3://${SNAP_BUCKET}/${SNAP_CLASS}/ …"
  local height
  height=$(aws s3 ls "s3://${SNAP_BUCKET}/${SNAP_CLASS}/" --no-sign-request |
           awk '{print $2}' | tr -d '/' | sort -n | tail -1)

  if [[ -z "$height" ]]; then
    echo "[✗] Could not determine snapshot height"; return 1
  fi

  # Confirm snapshot height
  read -rp "[?] Latest snapshot appears to be ${height}. Use this? [Y/n] " ans
  [[ "$ans" =~ ^[Nn]$ ]] && { echo "Aborted."; return 1; }

  # Download snapshot
  local snap_url="s3://${SNAP_BUCKET}/${SNAP_CLASS}/${height}/${height}.tar.gz"
  echo "[+] Ready to download:  ${snap_url}"
  read -rp "[?] Proceed with download? [y/N] " ans
  [[ "$ans" =~ ^[Yy]$ ]] || { echo "Aborted."; return 1; }

  echo "[→] Downloading …"
  aws s3 cp "$snap_url" "$HOME/.mayanode/data" --no-sign-request

  # Extract snapshot
  echo "[+] Snapshot saved as ~/.mayanode/data/${height}.tar.gz"
  read -rp "[?] Extract it into ~/.mayanode now? [y/N] " ans
  [[ "$ans" =~ ^[Yy]$ ]] || { echo "Aborted."; return 1; }

  tarball="$HOME/.mayanode/data/${height}.tar.gz"
  if command -v pv >/dev/null; then
      pv "$tarball" | tar xzf - -C "$HOME/.mayanode"
  else
      tar xzf "$tarball" -C "$HOME/.mayanode"
  fi

  # Integrity check
  [[ -d "$HOME/.mayanode/data/application.db" ]] || {
        echo "[✗] Snapshot extraction looks incomplete"; return 1; }
  # Remove tarball
  read -rp "[?] Delete the downloaded tarball to save space? [Y/n] " ans
  if [[ ! "$ans" =~ ^[Nn]$ ]]; then
    rm "$HOME/.mayanode/data/${height}.tar.gz"
    echo "[✓] Tarball removed"
  else
    echo "[i] Tarball kept as ~/.mayanode/data/${height}.tar.gz"
  fi

  # Sanity-check
  if [[ -d "$HOME/.mayanode/data/application.db" ]]; then
    echo -e "\n[✓] Snapshot looks good. You can now start the service."
    return 0
  else
    echo -e "\n[✗] application.db missing – something went wrong."
    return 1
  fi
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
  run_step "Install Go"                         install_go
  run_step "Add Go env vars"                    add_go_env
  run_step "Install required apt packages"      install_packages
  run_step "Install Docker & Compose"           install_docker
  run_step "Install AWS CLI"                    install_aws_cli
  run_step "Clone / build Mayanode"             install_mayanode
  run_step "Create systemd service"             create_service
  run_step "Install Mayanode binary"            install_binary
  run_step "Fetch & extract latest snapshot"    fetch_snapshot
  run_step "Configure UFW firewall"             setup_ufw
  run_step "Enable & start Mayanode service"    enable_service

  banner "All done! 🎉"
  echo "Use   sudo journalctl -feu mayanode   to follow logs."
}

main "$@"
