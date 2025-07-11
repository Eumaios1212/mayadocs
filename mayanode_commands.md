# Important Commands for Mayanode

## MAYAChain ABCI: Application layer

### Top-level status object (everything)


```bash
mayanode status | jq .
```

### Current network (mainnet / stagenet / testnet):

```bash
mayanode status | jq '.NodeInfo.network'
```

### Height and sync status:
```bash
mayanode status \
     | jq '.SyncInfo | {height: .latest_block_height, catching_up}'
```

### Node address & voting power (0 → not a validator)
```bash
mayanode status \
  | jq '.ValidatorInfo | {address: .Address, voting_power: .VotingPower|tonumber}'
```

## Tendermint / CometBFT RPC:  Consensus + P2P infrastructure layer

### Peer count
```bash
curl -s http://localhost:27147/net_info \
  | jq '.result.n_peers'
```

### Block time lag (how many seconds you trail the network)
```bash
curl -s http://localhost:27147/status \
  | jq '.result.sync_info.latest_block_time' -r \
  | xargs -I{} date -d {} +%s \
  | awk -v now=$(date +%s) '{print now - $1 " s behind"}'
```


### Connected peers: TendermintID@IP
```bash
curl -s http://localhost:27147/net_info \
  | jq '.result.peers
        | map("\(.node_info.id)@\(.remote_ip):27146")'
```

### Chain tag peers are running: ***NO OUTPUT***
```bash
curl -s http://localhost:27147/net_info \
| jq -r '.result.peers[]
        | .application_version.version // empty' \
| sort -u
```

### Current proposer & round/step
```bash
curl -s http://localhost:27147/dump_consensus_state \
  | jq -r '.result.round_state.height_round_step'
```
### All pools – giant JSON array

```bash
curl -s http://localhost:1317/mayachain/pools | jq .
```
```bash
curl -s http://localhost:1317/mayachain/pools | jq '.[0,1]'   # show first 2 entries
```

### Size of LevelDBs (quick disk-usage check)
```bash
du -sh ~/.mayanode/data/*db
```

## System monitoring

### RAM & CPU for the running process
```bash
PID=$(pgrep -f "mayanode start" | head -n1)
ps -p "$PID" -o rss,pmem,pcpu,etime,cmd
```

### `journalctl` logs for mayanode service

#### Show all logs
```bash
journalctl -u mayanode
```

#### Show latest logs
```bash
journalctl -u mayanode -r
```

#### Follow logs in real-time
```bash
journalctl -u mayanode -f
```

#### See what happened yesterday
```bash
journalctl -u mayanode --since yesterday
```

#### Show only WARNING and higher

```bash
journalctl -u mayanode -p warning
```

#### Save the last two weeks of logs to a file

```bash
journalctl -u mayanode --since "-14d" > mayanode_last14d.log
```

#### Filter logs
```bash
journalctl -u mayanode -f \
  | grep -v -e 'MsgTssKeysignFail' \
            -e 'cleaning pending liquidity'
```

# Upgrade Mayanode

## Show the top-level keys
`aws s3 ls s3://public-snapshots-mayanode/ --no-sign-request`

## Show latest pruned snapshot height (keep for next step)
```bash
aws s3 ls s3://public-snapshots-mayanode/pruned/ --no-sign-request \
| awk '{print $2}' | sed 's|/||' | sort -n | tail -n1

```

## Download the pruned archive
```bash
aws s3 cp \
  "s3://public-snapshots-mayanode/pruned/<snapshot#>/<snapshot#>.tar.gz" \
  ~/.mayanode/data/ --no-sign-request

```

## Backup & remove old data directory
```bash
cd ~/.mayanode
cp -a data "backup-data-$(date +%Y%m%d-%H%M%S)"
rm -rf ~/.mayanode/data/
```

## Extract and clean up
```bash
cd ~/.mayanode
pv <snapshot#>.tar.gz | tar xzf -
rm data/<snapshot#>.tar.gz

```
