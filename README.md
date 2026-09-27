# eth-node-healthcheck

A bash health check for an Ethereum execution client, with exit codes that monitoring systems
understand. It works with Geth, Nethermind, Reth, Erigon and Besu, or with any RPC URL.

```bash
./check.sh                                   # http://127.0.0.1:8545
./check.sh https://ethereum-rpc.publicnode.com
./check.sh -w 30 -c 120 -p 10 http://node:8545
```

```
$ ./check.sh https://ethereum-rpc.publicnode.com
OK - block 26040796, 7s old, 43 peers | age=7s peers=43
```

| check | default | state |
|---|---|---|
| `eth_syncing` returns an object | | WARNING, with current and highest block |
| head block older than `-w` / `-c` seconds | 60 / 300 | WARNING / CRITICAL |
| `net_peerCount` below `-p` | 5 | WARNING, skipped if the method is disabled |
| RPC unreachable | | UNKNOWN |

The exit codes follow the Nagios/Icinga plugin convention (0 OK, 1 WARNING, 2 CRITICAL, 3 UNKNOWN)
and the part after `|` is perfdata. It can run under Nagios, Icinga or Zabbix, from a systemd timer, or
from cron with something like `|| notify-me`.

Needs `bash`, `curl` and `jq`.
