## InterPol

InterPol is a protocol allowing users to lock their liquidity, no matter the duration, without having to renounce to the rewards possible.

Lock your LP tokens, stake in any of the protocols we support and start earning rewards!

## How it works

The protocol's two most important contracts are  `HoneyQueen` and `HoneyLocker`.

### HoneyQueen

This is the contract that acts as a registry for whitelisting protocols, their gauges/staking contracts and the functions associated to staking/unstaking/claiming rewards. This allows the maximum flexibility when it comes to integrating protocols.

### HoneyLocker

This is your locker contract, the one that holds your LP tokens. You deposit, stake, claim rewards and withdraw on this contract.

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
