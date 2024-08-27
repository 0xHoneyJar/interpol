## HoneyVault

HoneyVault is a smart contract that allows users to deposit and lock LP tokens without renouncing to the rewards these tokens can yield.

### Supported Protocols

| Protocol    | Supported |
| ----------- | --------- |
| BGT Station | ✅        |
| Kodiak      | ✅        |

## Deployments

### Beekeepr

For some reason, bundling the deployment and verification fails.

```
source .env && forge script script/Beekeeper.s.sol:BeekeeperDeploy --broadcast --slow --legacy --rpc-url https://bartio.rpc.berachain.com/

forge verify-contract >address< src/Beekeeper.sol:Beekeeper --verifier-url "https://api.routescan.io/v2/network/testnet/evm/80084/etherscan/api" --etherscan-api-key "verifyContract" --num-of-optimizations 200 --compiler-version 0.8.23 --watch
```

### Honey Queen

```
source .env && forge script script/HoneyQueen.s.sol:HoneyQueenDeploy --broadcast --slow --legacy --rpc-url https://bartio.rpc.berachain.com/

forge verify-contract >address< src/HoneyQueen.sol:HoneyQueen --verifier-url "https://api.routescan.io/v2/network/testnet/evm/80084/etherscan/api" --etherscan-api-key "verifyContract" --num-of-optimizations 200 --compiler-version 0.8.23 --watch
```

### Factory

```
source .env && forge script script/Factory.s.sol:FactoryDeploy --broadcast --slow --legacy --rpc-url https://bartio.rpc.berachain.com/

forge verify-contract >address< src/Factory.sol:Factory --verifier-url "https://api.routescan.io/v2/network/testnet/evm/80084/etherscan/api" --etherscan-api-key "verifyContract" --num-of-optimizations 200 --compiler-version 0.8.23 --watch
```
