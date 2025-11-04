# Beacon Proxy Pattern on Rootstock

A complete implementation of the **Beacon Proxy Pattern** for upgradeable smart contracts on Rootstock, built with Foundry and OpenZeppelin Contracts.

## Overview

This tutorial demonstrates how to build modular, upgradeable smart contracts on Rootstock using the **Beacon Proxy Pattern**. Unlike traditional proxies that reference their own logic contracts, beacon proxies use a central beacon to store the implementation address. Multiple proxies delegate calls via this beacon, allowing synchronized upgrades by simply updating the beacon.

### Key Benefits

- ✅ **Synchronized Upgrades**: Upgrade all proxies simultaneously by updating a single beacon
- ✅ **Gas Efficiency**: No need to upgrade each proxy individually
- ✅ **Storage Separation**: Each proxy maintains independent storage while sharing logic
- ✅ **Scalability**: Deploy unlimited proxies that all upgrade together
- ✅ **Maintainability**: Single point of upgrade management

## Architecture

```
                    ┌─────────────────┐
                    │  Beacon Contract│
                    │  (stores impl)  │
                    └────────┬────────┘
                             │
                ┌────────────┼────────────┐
                │            │            │
        ┌───────▼──────┐ ┌──▼──────┐ ┌───▼──────┐
        │ BeaconProxy 1│ │BeaconProxy 2││BeaconProxy N│
        │  (storage 1) │ │ (storage 2) ││ (storage N) │
        └───────┬──────┘ └──┬──────┘ └───┬──────┘
                │            │            │
                └────────────┼────────────┘
                             │
                    ┌────────▼────────┐
                    │ Implementation  │
                    │  Contract (V1)  │
                    │    or (V2)      │
                    └─────────────────┘
```

## Project Structure

```
Beacon_Proxy_Rootstock/
├── src/
│   ├── BoxV1.sol          # Initial implementation contract
│   └── BoxV2.sol          # Upgraded implementation with new features
├── script/
│   ├── DeployBeaconProxy.s.sol  # Deployment script
│   └── UpgradeBeacon.s.sol      # Upgrade script
├── test/
│   └── BeaconProxy.t.sol        # Comprehensive tests
├── lib/
│   └── openzeppelin-contracts-upgradeable/  # OpenZeppelin contracts
└── foundry.toml           # Foundry configuration for Rootstock
```

## Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation) installed
- Basic knowledge of Solidity and smart contracts
- A Rootstock testnet RPC endpoint (for deployment)

## Installation

1. Clone the repository:
```bash
git clone https://github.com/sainath5001/Beacon_Proxy_Rootstock.git
cd Beacon_Proxy_Rootstock
```

2. Install dependencies:
```bash
forge install OpenZeppelin/openzeppelin-contracts-upgradeable
```

3. Build the project:
```bash
forge build
```

## Quick Start

### 1. Run Tests

Test the beacon proxy pattern locally:

```bash
forge test
```

For verbose output:

```bash
forge test -vvv
```

### 2. Deploy to Local Network

Start a local Anvil node:

```bash
anvil
```

In another terminal, deploy:

```bash
forge script script/DeployBeaconProxy.s.sol:DeployBeaconProxy --rpc-url http://localhost:8545 --private-key <your-private-key> --broadcast
```

### 3. Deploy to Rootstock Testnet

Set up environment variables:

```bash
export PRIVATE_KEY=your_private_key_here
export ROOTSTOCK_TESTNET_RPC=https://public-node.testnet.rsk.co
```

Deploy to Rootstock testnet:

```bash
forge script script/DeployBeaconProxy.s.sol:DeployBeaconProxy \
  --rpc-url $ROOTSTOCK_TESTNET_RPC \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify
```

### 4. Upgrade the Beacon

After deploying BoxV1 and the beacon, you can upgrade to BoxV2:

```bash
export BEACON_ADDRESS=<beacon-address>
export PROXY_1_ADDRESS=<proxy1-address>
export PROXY_2_ADDRESS=<proxy2-address>
export PROXY_3_ADDRESS=<proxy3-address>

forge script script/UpgradeBeacon.s.sol:UpgradeBeacon \
  --rpc-url $ROOTSTOCK_TESTNET_RPC \
  --private-key $PRIVATE_KEY \
  --broadcast
```

## Contracts Explained

### BoxV1 (Initial Implementation)

`BoxV1` is a simple storage contract demonstrating the upgradeable pattern:

- **Storage**: Stores a `uint256` value
- **Ownership**: Access control for value modifications
- **Initialization**: Uses OpenZeppelin's `Initializable` for proxy compatibility

**Key Features:**
- `initialize(uint256 initialValue, address initialOwner)`: Initializes the contract
- `getValue()`: Returns the stored value
- `setValue(uint256 newValue)`: Updates the value (owner only)
- `transferOwnership(address newOwner)`: Transfers ownership

### BoxV2 (Upgraded Implementation)

`BoxV2` extends `BoxV1` with new features while maintaining storage compatibility:

**New Features:**
- `getVersion()`: Returns the contract version
- `increment()` / `decrement()`: Convenience functions for value manipulation
- `getValueFromHistory(uint256 index)`: Retrieve historical values
- `getHistoryCount()`: Get total number of value changes
- `migrateToV2()`: Migration function to enable V2 features

**Important:** When upgrading, existing storage slots remain unchanged, preserving data across upgrades.

### UpgradeableBeacon

The beacon contract stores the current implementation address and allows the owner to upgrade it. All proxy contracts query the beacon to get the implementation address.

**Important Note**: Once deployed, the beacon contract address is immutable and cannot be changed. All proxies reference this beacon address permanently, so choose your deployment network carefully.

### BeaconProxy

Proxy contracts that:
- Store their own state (independent storage)
- Delegate calls to the implementation via the beacon
- Automatically use the latest implementation after beacon upgrade

## Step-by-Step Tutorial

### Step 1: Deploy Implementation Contract

First, deploy the implementation contract (BoxV1). This contract contains the business logic but never stores user data directly.

```solidity
BoxV1 implementation = new BoxV1();
```

### Step 2: Deploy UpgradeableBeacon

Deploy the beacon contract, passing the implementation address and your address as the owner:

```solidity
UpgradeableBeacon beacon = new UpgradeableBeacon(
    address(implementation),
    deployer // owner who can upgrade
);
```

### Step 3: Deploy BeaconProxy Instances

Deploy multiple proxy instances, each pointing to the same beacon:

```solidity
bytes memory initData = abi.encodeWithSelector(
    BoxV1.initialize.selector,
    100, // initial value
    deployer // owner
);

BeaconProxy proxy1 = new BeaconProxy(address(beacon), initData);
BeaconProxy proxy2 = new BeaconProxy(address(beacon), initData);
BeaconProxy proxy3 = new BeaconProxy(address(beacon), initData);
```

Each proxy:
- Has independent storage (different values can be set)
- Shares the same implementation via the beacon
- Can be upgraded simultaneously

### Step 4: Interact with Proxies

Interact with proxies as if they were regular contracts:

```solidity
BoxV1 box1 = BoxV1(address(proxy1));
box1.setValue(999);
uint256 value = box1.getValue(); // returns 999
```

### Step 5: Upgrade All Proxies

To upgrade all proxies at once:

1. Deploy the new implementation (BoxV2):

```solidity
BoxV2 newImplementation = new BoxV2();
```

2. Upgrade the beacon:

```solidity
beacon.upgradeTo(address(newImplementation));
```

3. All proxies now use BoxV2! Migrate to enable V2 features:

```solidity
BoxV2 box1 = BoxV2(address(proxy1));
box1.migrateToV2(); // Enable V2 features

box1.increment(); // New V2 function!
```

## Understanding Storage Layout

⚠️ **Critical**: When upgrading contracts, you must maintain storage layout compatibility.

### V1 Storage Layout:
```solidity
slot 0: uint256 _value
slot 1: address _owner
```

### V2 Storage Layout:
```solidity
slot 0: uint256 _value      // Same as V1
slot 1: address _owner        // Same as V1
slot 2: uint256 _version      // NEW - appended
slot 3: mapping(...)          // NEW - appended
slot 4: uint256 _historyCount // NEW - appended
```

**Rule**: New storage variables must be appended, never inserted between existing ones.

## Testing

The test suite covers:

- ✅ Initial deployment and initialization
- ✅ Multiple proxies with independent storage
- ✅ Shared implementation via beacon
- ✅ Access control and permissions
- ✅ Beacon upgrade functionality
- ✅ Storage preservation across upgrades
- ✅ V2 feature migration
- ✅ Simultaneous upgrade of all proxies

Run specific tests:

```bash
# Run all tests
forge test

# Run with gas report
forge test --gas-report

# Run a specific test
forge test --match-test test_UpgradeBeaconToV2
```

## Deployment to Rootstock

### Rootstock Testnet

View deployed contracts on the [Rootstock Testnet Explorer](https://explorer.testnet.rootstock.io/).

```bash
forge script script/DeployBeaconProxy.s.sol:DeployBeaconProxy \
  --rpc-url $ROOTSTOCK_TESTNET_RPC \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify \
  --slow
```

### Rootstock Mainnet

⚠️ **WARNING**: Only deploy to mainnet after thorough testing!

```bash
forge script script/DeployBeaconProxy.s.sol:DeployBeaconProxy \
  --rpc-url https://public-node.rsk.co \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify \
  --slow
```

## Environment Variables

Create a `.env` file:

```bash
PRIVATE_KEY=your_private_key_here
ROOTSTOCK_TESTNET_RPC=https://public-node.testnet.rsk.co
ROOTSTOCK_API_KEY=your_blockscout_api_key_here  # For verification
BEACON_ADDRESS=0x...  # Set after deployment (immutable once deployed)
PROXY_1_ADDRESS=0x...
PROXY_2_ADDRESS=0x...
PROXY_3_ADDRESS=0x...
```

## Security Considerations

1. **Beacon Ownership**: The beacon owner has significant power - secure the owner key
2. **Implementation Validation**: Always verify implementation contracts before upgrading
3. **Storage Layout**: Never modify existing storage variable order
4. **Initialization**: Ensure contracts are properly initialized
5. **Access Control**: Review and test access control mechanisms

## Common Patterns

### Pattern 1: Factory with Beacon

Deploy proxies via a factory contract for gas efficiency:

```solidity
contract BoxFactory {
    UpgradeableBeacon public beacon;
    
    function createBox(uint256 initialValue) external returns (address) {
        bytes memory initData = abi.encodeWithSelector(
            BoxV1.initialize.selector,
            initialValue,
            msg.sender
        );
        
        BeaconProxy proxy = new BeaconProxy(address(beacon), initData);
        return address(proxy);
    }
}
```

### Pattern 2: Multi-Signature Beacon Owner

Use a multisig wallet as the beacon owner for enhanced security:

```solidity
UpgradeableBeacon beacon = new UpgradeableBeacon(
    address(implementation),
    multisigWalletAddress  // Multi-sig as owner
);
```

## Troubleshooting

### Error: "caller is not the owner"
- Ensure you're using the correct address to call owner-only functions
- Check that the proxy was initialized with the correct owner

### Error: "Contract is not initializing"
- Make sure `initialize()` is called during proxy deployment
- Don't call `initialize()` more than once

### Error: "Storage layout incompatible"
- Review storage variable order between V1 and V2
- Ensure new variables are appended, not inserted

## Resources

- [OpenZeppelin Beacon Proxy Documentation](https://docs.openzeppelin.com/contracts/4.x/api/proxy#beacon)
- [Foundry Book](https://book.getfoundry.sh/)
- [Rootstock Documentation](https://rootstock.io/dev/)
- [Rootstock Testnet Explorer](https://explorer.testnet.rootstock.io/)
- [EIP-1967: Proxy Storage Slots](https://eips.ethereum.org/EIPS/eip-1967)

## License

MIT

## Contributing

Contributions are welcome! Please open an issue or submit a pull request.

## Authors

Built for Rootstock using Foundry and OpenZeppelin Contracts.

---

**Happy Building on Rootstock! 🚀**
