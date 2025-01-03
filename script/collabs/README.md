## How to deploy

### Boyco

```
source .env && forge script script/collabs/BoycoInterpol.s.sol:BoycoInterpolScript true  \
--rpc-url $RPC_URL \
--broadcast \
--verify \
--verifier-url https://api.routescan.io/v2/network/testnet/evm/80084/etherscan \
--etherscan-api-key verifyContract \
--chain-id 80084 --legacy --slow --sig "run(bool)"
```

<!-- ### Beekeeper

```
source .env && forge script script/Beekeeper.s.sol:BeekeeperDeploy \
--rpc-url https://bartio.rpc.berachain.com \
--broadcast \
--verify \
--verifier-url https://api.routescan.io/v2/network/testnet/evm/80084/etherscan \
--etherscan-api-key verifyContract \
--chain-id 80084 --legacy --slow
```

### Honey Queen

```
source .env && forge script script/HoneyQueen.s.sol:HoneyQueenDeploy \
--rpc-url https://bartio.rpc.berachain.com \
--broadcast \
--verify \
--verifier-url https://api.routescan.io/v2/network/testnet/evm/80084/etherscan \
--etherscan-api-key verifyContract \
--chain-id 80084 --legacy --slow
```

### Factory

```
source .env && forge script script/LockerFactory.s.sol:LockerFactoryDeploy \
--rpc-url https://bartio.rpc.berachain.com \
--broadcast \
--verify \
--verifier-url https://api.routescan.io/v2/network/testnet/evm/80084/etherscan \
--etherscan-api-key verifyContract \
--chain-id 80084 --legacy --slow
``` -->
