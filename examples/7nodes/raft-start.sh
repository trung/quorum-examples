#!/bin/bash
set -u
set -e
permissioned=(_ yes yes yes yes no no no)

function usage() {
  echo ""
  echo "Usage:"
  echo "    $0 [tessera | tessera-remote | constellation] [--tesseraOptions \"options for Tessera start script\"]"
  echo ""
  echo "Where:"
  echo "    tessera | tessera-remote | constellation (default = tessera): specifies which privacy implementation to use"
  echo "    --tesseraOptions: allows additional options as documented in tessera-start.sh usage which is shown below:"
  echo ""
  ./tessera-start.sh --help
  exit -1
}

NETWORK_ID=$(cat genesis.json | tr -d '\r' | grep chainId | awk -F " " '{print $2}' | awk -F "," '{print $1}')

if [ $NETWORK_ID -eq 1 ]
then
    echo "  Quorum should not be run with a chainId of 1 (Ethereum mainnet)"
    echo "  please set the chainId in the genensis.json to another value "
    echo "  1337 is the recommend ChainId for Geth private clients."
fi

mkdir -p qdata/logs

function startNode() {
	node=$1

	echo "[*] Start node $node"
	QUORUM_GETH_ARGS=${QUORUM_GETH_ARGS:-}
	NODE_GETH_ARGS=$(eval "echo \${`echo QUORUM_GETH_ARGS_${node}`:-}")
	ARGS="--nodiscover --verbosity 5 --networkid $NETWORK_ID --raft --rpc --rpcaddr 0.0.0.0 --rpcapi admin,db,eth,debug,miner,net,shh,txpool,personal,web3,quorum,raft --emitcheckpoints $QUORUM_GETH_ARGS $NODE_GETH_ARGS"
	if [[ "${permissioned[node]}" == "yes" ]]; then
		ARGS="$ARGS --permissioned"
	fi
	PRIVATE_CONFIG=qdata/c$node/tm.ipc nohup geth --datadir qdata/dd$node $ARGS --raftport $((50400 + $node)) --rpcport $((22000 + $node - 1)) --port $((21000 + $node - 1)) --unlock 0 --password passwords.txt 2>>qdata/logs/$node.log &
}

privacyImpl=tessera
tesseraOptions=
while (( "$#" )); do
    case "$1" in
        tessera)
            privacyImpl=tessera
            shift
            ;;
        constellation)
            privacyImpl=constellation
            shift
            ;;
        tessera-remote)
            privacyImpl="tessera-remote"
            shift
            ;;
        --tesseraOptions)
            tesseraOptions=$2
            shift 2
            ;;
        --help)
            shift
            usage
            ;;
		[1-7])
			startNode $1
			exit 0
			;;
        *)
            echo "Error: Unsupported command line parameter $1"
            usage
            ;;
    esac
done


if [ "$privacyImpl" == "tessera" ]; then
  echo "[*] Starting Tessera nodes"
  ./tessera-start.sh ${tesseraOptions}
elif [ "$privacyImpl" == "constellation" ]; then
  echo "[*] Starting Constellation nodes"
  ./constellation-start.sh
elif [ "$privacyImpl" == "tessera-remote" ]; then
  echo "[*] Starting tessera nodes"
  ./tessera-start-remote.sh ${tesseraOptions}
else
  echo "Unsupported privacy implementation: ${privacyImpl}"
  usage
fi

echo "[*] Starting Ethereum nodes with ChainID and NetworkId of $NETWORK_ID"
for i in {1..7}
do
	startNode $i
done

echo
echo "All nodes configured. See 'qdata/logs' for logs, and run e.g. 'geth attach qdata/dd1/geth.ipc' to attach to the first Geth node."
echo "To test sending a private transaction from Node 1 to Node 7, run './runscript.sh private-contract.js'"

exit 0
