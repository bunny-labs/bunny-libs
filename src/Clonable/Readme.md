# `Clonable.sol` - clonable smart contracts

## How is it useful?

- For developers:
  - A way to monetize your smart contracts
  - Easy to use library for implementing contract factories
- For end users:
  - Cheaper to deploy contracts -- you typically save on gas even after author fees.
  - Easier to deploy contracts -- no need to set up a dev environment, if you know how to interact with contracts on Etherscan, you can clone!

## How does it work?

1. Developer implements and deploys a contract that inherits from `Clonable` (see detailed implementation guide below). They can specify a % of the storage gas cost saved that will be charged as a cloning fees when users deploy their own copies of the contract. The fee % can be updated later, along with a fee recipient and contract author addresses.
2. A user finds a clonable contract and wants to deploy their own copy. They can either use Etherscan (see detailed cloning guide below) or a dedicated frontend (if provided by the developer) to clone it. In either case, the basic steps are as follows:
   1. Get the contract's cloning fee from the contract
   2. Prepare initialization data
   3. Call the `clone()` method and pass along the cloning fee and data from the previous steps.
3. A minimal clone contract is deployed for the user that is identical in terms of functionality to the original. The end user saves gas on deployment costs thanks to the cloning mechanism and the contract author is rewarded with a share of those savings.

## Background

The most expensive on-chain operations are those that store data.
This includes the bytecode that is written to the blockchain when deploying smart contracts.
While these costs are less significant during periods of low ETH price and little activity, they can be considerable when in the middle of a bull mania.

When deploying a series of functionally identical contracts, the costs can be reduced with very little downside.
This is achieved by deploying [minimal proxy contracts (EIP-1167)](https://eips.ethereum.org/EIPS/eip-1167) that delegate their logic to an existing contract on the blockchain instead of duplicating its full bytecode.
These contracts are always 45 bytes long, regardless of the size of the original, and therefore much cheaper to deploy.
They are also immutable, provide the full functionality of the original contract and have first-class support on popular blockchain explorers like Etherscan.

OpenZeppelin provides the [Clones](https://docs.openzeppelin.com/contracts/4.x/api/proxy#Clones) library to deploy these minimal proxies but `Clonable` takes it a step further by implementing the functionality in a simple base contract and adding the option for charging author fees.
Developers can add cloning support to any of their contracts by inheriting from `Clonable` and following a few simple implementation guidelines.

## Developers: Implementation guide

Adding cloning support to your contract is fairly straightforward.
Following code snippets are based on the `Distributor` contract from [bunny-labs/smart-contracts](https://github.com/bunny-labs/smart-contracts/tree/main/src/Distributor), see the original repository for a full implementation.

### 1. Install `bunny-libs`.

```bash
forge install bunny-labs/bunny-libs
```

### 2. Inherit from `Clonable`

Add an import for the base contract.

```solidity
import "bunny-libs/Clonable/Clonable.sol";
```

And make your contract inherit from `Clonable`.

```solidity
contract Distributor is MembershipToken, Clonable {
  ...
```

### 3. Implement the `_initializer()` method.

`Clonable` requires you to implement an internal function for performing your contract-specific initialization.
The initializer accepts contract parameters as a single `bytes`-encoded argument to keep the interface uniform across all different kinds of clonable contracts.

This initializer should:

- decode `bytes`-encoded contract parameters,
- perform any initialization needed for the contract to function.

```solidity
function _initialize(bytes memory initdata) internal override {
    (string memory name_, string memory symbol_, Membership[] memory members_) = abi.decode(initdata, (string, string, Membership[]));
    MembershipToken._initialize(name_, symbol_, members_);
}
```

The initializer will be called from:

- `constructor()` when deploying the original contract
- `initializeClone()` when deploying clones

### 4. Update your constructor.

- Add the `initializer` modifier. This will prevent contract instances from being reinitialized after deployment.
- Add a parameter for cloning configuration. We need to pass this on to `Clonable`.
- Initialize `Clonable`. This will set up initial cloning parameters like contract author, fee bps and fee recipient.
- Move the actual initialization logic into `_initialize(bytes memory initdata)`.

```solidity
constructor(
    string memory name_,
    string memory symbol_,
    Membership[] memory members_,
    CloningConfig memory cloningConfig
) initializer Clonable(cloningConfig) {
    _initialize(abi.encode(name_, symbol_, members_));
}
```

### (Optional) 5. Implement helpers for encoding and decoding initialization data.

The `clone(bytes memory initdata)` function for deploying clones accepts `bytes`-encoded initialization data.
This is non-trivial to generate manually which means that the contract cannot be easily cloned via Etherscan.

If you're planning on implementing a custom frontend for deploying your contracts, this can be a non-issue.
However if you're not planning on deploying a frontend or just want to keep cloning accessible via Etherscan, it is recommended to implement helpers for encoding/decoding `initdata` for your contract.

```solidity
function encodeInitdata(string memory name_, string memory symbol_, Membership[] memory members_)
    public
    pure
    returns (bytes memory)
{
    return abi.encode(name_, symbol_, members_);
}

function decodeInitdata(bytes memory initdata)
    public
    pure
    returns (string memory, string memory, Membership[] memory)
{
    return abi.decode(initdata, (string, string, Membership[]));
}
```

If you do, make sure to update your `_initializer()`

```solidity
function _initialize(bytes memory initdata) internal override {
    (string memory name_, string memory symbol_, Membership[] memory members_) = decodeInitdata(initdata);
    MembershipToken._initialize(name_, symbol_, members_);
}
```

and `constructor()`

```solidity
constructor(
      string memory name_,
      string memory symbol_,
      Membership[] memory members_,
      CloningConfig memory cloningConfig
  ) initializer Clonable(cloningConfig) {
      _initialize(encodeInitdata(name_, symbol_, members_));
  }
```

to use the helpers instead of `abi.encode` and `abi.decode` directly.
This helps avoid errors from accidentally different implementations.

## Users: Cloning guide

/_Coming soon._/
