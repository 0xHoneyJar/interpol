## How to deploy

### Boyco deploy

```
source .env && forge script script/collabs/boyco/Deploy.s.sol:Deploy false  \
--rpc-url $RPC_URL_MAINNET \
--broadcast \
--verify \
--verifier-url https://api.routescan.io/v2/network/mainnet/evm/80094/etherscan \
--etherscan-api-key verifyContract \
--chain-id 80094 --legacy --slow --sig "run(bool)" --force
```

### Boyco update
```
source .env && forge script script/collabs/boyco/Update.s.sol:Update false  \
--rpc-url $RPC_URL_MAINNET \
--broadcast \
--verify \
--verifier-url https://api.routescan.io/v2/network/mainnet/evm/80094/etherscan \
--etherscan-api-key verifyContract \
--chain-id 80094 --legacy --slow --sig "run(bool)" --force
```