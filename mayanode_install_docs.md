<h2 style="text-align: center;">
Fullnode Installation Guide
</h2>

#### Make sure ports 27146 & 1317 are open on firewall

#### Install required packages
```bash
sudo apt-get update && \
sudo apt-get install -y \
     git make protobuf-compiler curl wget jq build-essential musl-tools \
     pv gawk linux-headers-generic ca-certificates gnupg lsb-release lz4 unzip
```

#### Install Go
```bash
cd && \
sudo rm -rvf /usr/local/go/ && \
wget https://golang.org/dl/go1.22.2.linux-amd64.tar.gz && \
sudo tar -C /usr/local -xzf go1.22.2.linux-amd64.tar.gz && \
rm go1.22.2.linux-amd64.tar.gz
```
#### Add Go environment variables to .bash_profile, if not already set & source it
```bash
# Ensure ~/.bash_profile exists
touch ~/.bash_profile

# Only append Go env vars if not already present
if ! grep -q "GOROOT" ~/.bash_profile; then
    cat << 'EOF' >> ~/.bash_profile
export GOROOT=/usr/local/go
export GOPATH=$HOME/go
export GO111MODULE=on
export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin
EOF
fi

# Apply the changes
source ~/.bash_profile
```

#### Install Docker and Docker Compose plugin:
```bash
sudo mkdir -p /etc/apt/keyrings && \
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
 | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg && \
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null && \
sudo apt update && \
sudo apt install -y docker-ce docker-ce-cli containerd.io \
  docker-buildx-plugin docker-compose-plugin
```
> **Note**: For details see: https://docs.docker.com/engine/install/

#### Install AWS CLI, if not already installed
```bash
command -v aws >/dev/null || (
  curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
  unzip awscliv2.zip && \
  sudo ./aws/install && \
  rm -rf aws awscliv2.zip
)
```

#### Install mayanode
```bash
git clone https://gitlab.com/mayachain/mayanode.git && \
cd mayanode && \
git fetch --tags && \
LATEST_TAG=$(git tag --sort=version:refname | tail -n 1) && \
echo "Checking out latest tag: $LATEST_TAG" && \
git checkout "$LATEST_TAG" && \
make protob
```

#### Add env Variables for Radix and ZCash
```bash
# Ensure ~/.bash_profile exists
touch ~/.bash_profile

# Only append LD_LIBRARY_PATH if not already present
if ! grep -q "LD_LIBRARY_PATH.*mayanode" ~/.bash_profile; then
    if [ -d "$HOME/mayanode/lib/" ]; then
        if [ -f "$HOME/mayanode/lib/libradix_engine_toolkit_uniffi.so" ] && [ -f "$HOME/mayanode/lib/libzec.so" ]; then
            cat << 'EOF' >> ~/.bash_profile
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$HOME/mayanode/lib/
EOF
            echo "Added LD_LIBRARY_PATH to ~/.bash_profile for $HOME/mayanode/lib/"
        else
            echo "Error: One or both libraries (libradix_engine_toolkit_uniffi.so, libzec.so) not found in $HOME/mayanode/lib/"
            echo "Ensure the Maya node build completed successfully."
            exit 1
        fi
    else
        echo "Error: $HOME/mayanode/lib/ does not exist. Please build the Maya node first."
        exit 1
    fi
else
    echo "LD_LIBRARY_PATH already includes $HOME/mayanode/lib/ in ~/.bash_profile"
fi

# Apply bash_profile changes
source ~/.bash_profile
echo "Environment updated. LD_LIBRARY_PATH now includes: $LD_LIBRARY_PATH"
```

#### Create mayanode.service File
```
CURRENT_USER="${SUDO_USER:-$(whoami)}"
cat <<EOF | sudo tee /etc/systemd/system/mayanode.service > /dev/null
[Unit]
Description="Mayanode"
After=network-online.target

[Service]
User=$CURRENT_USER
WorkingDirectory=/home/$CURRENT_USER/mayanode
ExecStartPre=/home/$CURRENT_USER/go/bin/mayanode render-config
ExecStart=/home/$CURRENT_USER/go/bin/mayanode start
Restart=always
RestartSec=3
LimitNOFILE=4096
Environment="LD_LIBRARY_PATH=/home/$CURRENT_USER/mayanode/lib"
Environment="MAYA_COSMOS_TELEMETRY_ENABLED=true"
Environment="CHAIN_ID=mayachain-mainnet-v1"
Environment="NET=mainnet"
Environment="SIGNER_NAME=mayachain"
Environment="SIGNER_PASSWD=password"

[Install]
WantedBy=multi-user.target
EOF
```
#### Install binary
```
TAG=mainnet NET=mainnet make install
```

#### Fetch and extract Latest Pruned Snapshot
> Ensure at least 750GB free space due to the snapshot’s size.
```bash
mkdir -p ~/.mayanode/data

# Fetch the latest snapshot height (switch to "full" if you want full snapshot)
echo "[+] Fetching latest snapshot height..."
LATEST_HEIGHT=$(aws s3 ls s3://public-snapshots-mayanode/pruned/ --no-sign-request | \
  awk '{print $2}' | sed 's|/||' | sort -n | tail -n 1)

if [ -z "$LATEST_HEIGHT" ]; then
  echo "[✗] Failed to determine latest snapshot height"
  exit 1
else
  echo "[✓] Latest snapshot height: $LATEST_HEIGHT"
fi

# Download the snapshot
echo "[+] Downloading snapshot archive..."
aws s3 cp "s3://public-snapshots-mayanode/pruned/${LATEST_HEIGHT}/${LATEST_HEIGHT}.tar.gz" \
  ~/.mayanode/data --no-sign-request

if [ $? -ne 0 ]; then
  echo "[✗] Snapshot download failed"
  exit 1
else
  echo "[✓] Snapshot downloaded"
fi

# Extract the snapshot
echo "[+] Extracting snapshot archive..."
pv ~/.mayanode/data/${LATEST_HEIGHT}.tar.gz | tar xz -C ~/.mayanode

if [ $? -ne 0 ]; then
  echo "[✗] Snapshot extraction failed"
  exit 1
else
  echo "[✓] Snapshot extracted successfully"
fi

# Clean up archive
echo "[+] Cleaning up archive file..."
rm ~/.mayanode/data/${LATEST_HEIGHT}.tar.gz && \
echo "[✓] Archive removed" || echo "[!] Failed to remove archive (harmless)"

# Verify final directory structure
echo "[+] Verifying snapshot contents..."
if [ -d ~/.mayanode/data/application.db ]; then
  echo "[✓] Snapshot appears valid and ready"
else
  echo "[✗] Snapshot structure incomplete or incorrect"
  exit 1
fi

```
> **Note**: Snapshots can be found here: https://public-snapshots-mayanode.s3.amazonaws.com/full/index.html

#### Setup UFW
sudo ufw allow 27146/tcp    # P2P
sudo ufw allow 1317/tcp     # Tendermint (REST/monitoring)
sudo ufw reload

#### Start Service & Confirm it's running
```
sudo systemctl daemon-reload && \
sudo systemctl enable mayanode.service	&& \
sudo systemctl start mayanode && \
sudo systemctl status mayanode
```
#### Check logs
```
sudo journalctl -feu mayanode			# Check logs
```
