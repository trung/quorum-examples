#!/bin/bash

# only node 1-4 are permissioned
permissioned=(_ yes yes yes yes no no no)

node=$1
fromNode=1
toNode=$((${#permissioned[@]} - 1))


function init() {
	node=$1
	rm -rf qdata/dd$node
	rm -rf qdata/c$node
	rm -rf qdata/logs/*$node.log
	
	perm=${permissioned[node]}
	echo "[*] Configuring node $node (permissioned=$perm)"
	mkdir -p qdata/dd$node/{keystore,geth}
	cp permissioned-nodes.json qdata/dd$node/static-nodes.json
	cp keys/key$node qdata/dd$node/keystore
	cp raft/nodekey$node qdata/dd$node/geth/nodekey
	if [[ "$perm" == "yes" ]]; then
		cp permissioned-nodes.json qdata/dd$node/
	fi
	geth --datadir qdata/dd$node init genesis.json
}

case "$node" in
	[1-7])
		fromNode=$node
		toNode=$node
		;;
	*)
		;;
esac

for i in `eval "echo {$fromNode..$toNode}"`
do
	init $i
done

#Initialise Tessera configuration
./tessera-init.sh
