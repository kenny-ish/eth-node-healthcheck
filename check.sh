#!/usr/bin/env bash
# Health check for an Ethereum execution client.
# Exit codes: 0 OK, 1 WARNING, 2 CRITICAL, 3 UNKNOWN (Nagios plugin convention).
set -euo pipefail

usage() {
  echo "usage: $0 [-w warn_age_s] [-c crit_age_s] [-p min_peers] [RPC_URL]" >&2
  exit 3
}

warn_age=60
crit_age=300
min_peers=5
while getopts "w:c:p:h" opt; do
  case "$opt" in
    w) warn_age=$OPTARG ;;
    c) crit_age=$OPTARG ;;
    p) min_peers=$OPTARG ;;
    *) usage ;;
  esac
done
shift $((OPTIND - 1))
rpc="${1:-http://127.0.0.1:8545}"

call() {
  curl -fsS -m 10 -H 'Content-Type: application/json' \
    -d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"$1\",\"params\":${2:-[]}}" "$rpc"
}

if ! syncing=$(call eth_syncing | jq -c '.result'); then
  echo "UNKNOWN - $rpc not reachable"
  exit 3
fi

block_json=$(call eth_getBlockByNumber '["latest", false]')
number_hex=$(jq -r '.result.number' <<<"$block_json")
ts_hex=$(jq -r '.result.timestamp' <<<"$block_json")
number=$((16#${number_hex#0x}))
age=$(($(date +%s) - 16#${ts_hex#0x}))

peers="n/a"
if peers_hex=$(call net_peerCount | jq -er '.result' 2>/dev/null); then
  peers=$((16#${peers_hex#0x}))
fi

state=0
notes=()
if [[ $syncing != "false" ]]; then
  state=1
  cur=$(jq -r '.currentBlock // empty' <<<"$syncing")
  high=$(jq -r '.highestBlock // empty' <<<"$syncing")
  notes+=("syncing $((16#${cur#0x}))/$((16#${high#0x}))")
fi
if ((age > crit_age)); then
  state=2
  notes+=("head is ${age}s old")
elif ((age > warn_age)); then
  ((state < 1)) && state=1
  notes+=("head is ${age}s old")
fi
if [[ $peers != "n/a" ]] && ((peers < min_peers)); then
  ((state < 1)) && state=1
  notes+=("only $peers peers")
fi

labels=(OK WARNING CRITICAL)
summary="block $number, ${age}s old, $peers peers"
if ((${#notes[@]})); then
  summary="$(IFS=';'; echo "${notes[*]}") ($summary)"
fi
echo "${labels[$state]} - $summary | age=${age}s peers=${peers/n\/a/0}"
exit "$state"
