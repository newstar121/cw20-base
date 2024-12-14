#!/bin/bash

#Build Flag

NETWORK=testnet

export GOPATH=$HOME/go
export PATH=$PATH:$GOROOT/bin:$GOPATH/bin

OWNER="wallet"
RETURN=""

ADDR_OWNER=$(osmosisd keys show $OWNER -a)

echo "OWNER = $ADDR_OWNER" 
WALLET="--from $OWNER"

echo "osmosisd keys show $OWNER -a"

case $NETWORK in
    localnet)
        NODE="http://localhost:26657"
        DENOM="uosmo"
        CHAIN_ID="testchain-1"
        ;;
    testnet)
        NODE="https://rpc.testnet.osmosis.zone:443"
        DENOM="uosmo"
        CHAIN_ID="osmo-test-5"
        ;;
    mainnet)
        NODE="https://sei-rpc.polkachu.com:443"
        DENOM=uosmo
        CHAIN_ID=pacific-1
        ;; 
esac

NODECHAIN="--node $NODE --chain-id $CHAIN_ID"
TXFLAG="$NODECHAIN --gas=250000 --fees=250000uosmo --broadcast-mode block --keyring-backend test -y"

Execute() {
    CMD=$1
    # echo "**************BEGIN**********************" >> /root/Sei-IDO-Tier-Contract/command.txt
    # echo $CMD >> /root/Sei-IDO-Tier-Contract/command.txt
    # echo "------------------------------------------" >> /root/Sei-IDO-Tier-Contract/command.txt

    echo $CMD
    
    if  [[ $CMD == cd* ]] ; then
        $CMD > ~/out.log    
        RETURN=$(cat ~/out.log)
    else
        RETURN=$(eval $CMD)
    fi

    

    # echo $RETURN >> /root/Sei-IDO-Tier-Contract/command.txt
    # echo "*************END*************************" >> /root/Sei-IDO-Tier-Contract/command.txt
}

RustBuild() {
    CATEGORY=$1

    echo "================================================="
    echo "Rust Optimize Build Start for $CATEGORY"
    
    rm -rf target
    rm -rf release
    mkdir release

    Execute "RUSTFLAGS='-C link-arg=-s' cargo wasm"
    Execute "cp ./target/wasm32-unknown-unknown/release/$CATEGORY.wasm ./release/"
}


Upload() {
    CATEGORY=$1
    echo "================================================="
    echo "Upload Wasm for $CATEGORY"
    Execute "osmosisd tx wasm store release/$CATEGORY".wasm" $WALLET $NODECHAIN --gas-prices 0.1uosmo --gas auto --gas-adjustment 1.3 -y --output json | jq -r '.txhash'"
    UPLOADTX=$RETURN

    echo "Upload txHash: "$UPLOADTX
    echo "================================================="
    echo "GetCode"

    CODE_ID=""
    while [[ $CODE_ID == "" ]]
    do 
        sleep 3
        Execute "osmosisd query tx --type=hash $UPLOADTX $NODECHAIN --output json | jq -r '.events[-1].attributes[1].value'"
        CODE_ID=$RETURN
    done

    echo "$CATEGORY Contract Code_id: "$CODE_ID
    echo $CODE_ID > data/code_$CATEGORY
}

InstantiateCW20() {
    CATEGORY='cw20_base'
    echo "================================================="
    echo "Instantiate Contract "$CATEGORY
    #read from FILE_CODE_ID
    
    CODE_ID=$(cat data/code_$CATEGORY)

    echo "Code id: " $CODE_ID

    CONTRACT_OWNER='osmo16s2caj7d6gzez7kt34pphysqj3mw40gcqczrh4'

    Execute "osmosisd tx wasm instantiate $CODE_ID '{\"name\":\"EGG\",\"symbol\":\"EGG\",\"decimals\":6,\"initial_balances\":[{\"address\":\"'$CONTRACT_OWNER'\",\"amount\":\"1680000000000000\"}],\"mint\":{\"minter\":\"'$CONTRACT_OWNER'\"},\"marketing\":{\"marketing\":\"'$CONTRACT_OWNER'\",\"logo\":{\"url\":\"https://wz4hgrl45auboz6wybozukxwlne3kxb3ds2mtur4hnazrm4wr2iq.arweave.net/tnhzRXzoKBdn1sBdmir2W0m1XDsctMnSPDtBmLOWjpE/-1.png\"}}}' --label \"EGG\" --admin $CONTRACT_OWNER $WALLET $TXFLAG --output json | jq -r '.txhash'"
    TXHASH=$RETURN

    echo "Transaction hash = $TXHASH"
    CONTRACT_ADDR=""
    while [[ $CONTRACT_ADDR == "" ]]
    do
        sleep 3
        Execute "osmosisd query tx $TXHASH $NODECHAIN --output json | jq -r '.logs[0].events[0].attributes[0].value'"
        CONTRACT_ADDR=$RETURN
    done
    echo "Contract Address: " $CONTRACT_ADDR
    echo $CONTRACT_ADDR > data/contract_$CATEGORY
}

#################################################################################
PrintWalletBalance() {
    echo "native balance"
    echo "========================================="
    osmosisd query bank balances $ADDR_OWNER $NODECHAIN
    echo "========================================="
}


DeployCw20base() {
    CATEGORY=cw20_base
    RustBuild $CATEGORY
    Upload $CATEGORY
    # InstantiateCW20
}

DeployCw20base
PrintWalletBalance
