## InterPol

InterPoL is a protocol specially designed for the Berachain ecosystem which allows token creators, launchpads, protocols, and more, to deploy protocol-owned liquidity while retaining the ability to stake it and participate in Proof of Liquidity flywheels.

## Contracts

### BaseVaultAdapter

BaseVaultAdapter is an abstract contract that serves as the base implementation for all vault adapters in the protocol, defining core interfaces for staking, unstaking, and claiming rewards.

### AdapterFactory

AdapterFactory is a contract that creates adapter instances for lockers using a cloning mechanism, ensuring that only authorized adapters can be deployed through validation by HoneyQueen. It acts as a factory for creating adapter contracts that enable lockers to interact with various vaults while maintaining security through proper authorization checks.

### HoneyQueen

HoneyQueen is the central registry and configuration contract for the protocol. It maintains a list of approved adapter implementations for vaults, tracks blocked tokens and reward tokens, and handles protocol fee calculations. The contract also manages the adapter factory and beekeeper addresses, allowing only authorized adapters to be deployed through the factory.

### HoneyLocker

HoneyLocker is a contract that allows users to deposit and lock LP tokens for a specified duration while also enabling them to stake these tokens in various vaults through adapter contracts. It handles token management (including ERC20, ERC721, and ERC1155), manages vault interactions through adapters, and includes features for BGT staking and reward claiming, all while enforcing lock periods and handling protocol fees through the HoneyQueen contract.

### Beekeeper

Beekeeper is a contract that manages fee distribution between referrers and the treasury, allowing for customizable fee shares and referrer overrides. It includes features for setting standard and custom referrer fee shares in basis points, handling both native and ERC20 token distributions, and provides safety mechanisms like referrer overrides in case of compromised addresses.


## How to deploy

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
