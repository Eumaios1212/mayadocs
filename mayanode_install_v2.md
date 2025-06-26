<h2 style="text-align: center;">
Fullnode Installation Guide
</h2>

#### Make sure ports 27146 & 1317 are open on firewall

#### Install Go
```
cd && \
sudo rm -rvf /usr/local/go/ && \
wget https://golang.org/dl/go1.22.2.linux-amd64.tar.gz && \
sudo tar -C /usr/local -xzf go1.22.2.linux-amd64.tar.gz && \
rm go1.22.2.linux-amd64.tar.gz
```
#### Add go environment variables to .profile
```
cat << 'EOF' >> ~/.profile

export GOROOT=/usr/local/go
export GOPATH=$HOME/go
export GO111MODULE=on
export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin
EOF
```
#### Source .profile
```
source ~/.profile
```
#### Install required packages
```
sudo apt-get update && \
sudo apt-get install -y \
     git \
     make \
     protobuf-compiler \
     curl \
     wget \
     jq \
     build-essential \
     musl-tools \
     gawk \
     linux-headers-generic \
     ca-certificates \
     gnupg \
     lsb-release
```
#### Set up Docker:
```
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
#### Manage Docker as a Non-Root User
```
sudo groupadd docker && \
sudo usermod -aG docker $USER && \
newgrp docker
```
#### Install mayanode
```
git clone https://gitlab.com/mayachain/mayanode && \
cd mayanode && \
LATEST_TAG=$(git tag --sort=version:refname | tail -n 1) && \
git checkout "$LATEST_TAG" && \
make protob
```
#### Copy 'libradix_engine_toolkit_uniffi.so' to /usr/local/lib and update the system’s library cache:
```
sudo cp ~/mayanode/lib/libradix_engine_toolkit_uniffi.so /usr/local/lib/ && \
sudo ldconfig
```
#### Install binary
```
TAG=mainnet NET=mainnet make install
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
ExecStartPre=/home/$CURRENT_USER/go/bin/mayanode render-config
ExecStart=/home/$CURRENT_USER/go/bin/mayanode start
Restart=always
RestartSec=3
LimitNOFILE=4096
Environment="MAYA_COSMOS_TELEMETRY_ENABLED=true"
Environment="CHAIN_ID=mayachain-mainnet-v1"
Environment="NET=mainnet"
Environment="SIGNER_NAME=mayachain"
Environment="SIGNER_PASSWD=password"

[Install]
WantedBy=multi-user.target
EOF
```
#### Create ~/.mayanode:
```commandline
CURRENT_USER="${SUDO_USER:-$(whoami)}" && sudo -u "$CURRENT_USER" /home/"$CURRENT_USER"/go/bin/mayanode render-config
```
#### Backup original `data` dir, then download & unpack new snapshot
```
mv ~/.mayanode/data ~/.mayanode/data.bak && \
wget -O - "https://public-snapshots-mayanode.s3.us-east-2.amazonaws.com/pruned/10042648/10042648.tar.gz" \
    | tar -xz -C ~/.mayanode
```
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
