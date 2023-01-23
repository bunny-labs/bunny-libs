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

The most expensive on-chain operations are those that store data. This includes the bytecode that is written to the blockchain when deploying smart contracts. While these costs are less significant during periods of low ETH price and little activity, they can be considerable when in the middle of a bull mania.

When deploying a series of functionally identical contracts, the costs can be reduced with very little downside. This is achieved by deploying [minimal proxy contracts (EIP-1167)](https://eips.ethereum.org/EIPS/eip-1167) that delegate their logic to an existing contract on the blockchain instead of duplicating its full bytecode. These contracts are always 45 bytes long, regardless of the size of the original, and therefore much cheaper to deploy. OpenZeppelin provides the [Clones](https://docs.openzeppelin.com/contracts/4.x/api/proxy#Clones) library to do just that.

`Clonable` takes this a step further by combining all of this in a simple base contract. Developers can add cloning support to any of their contracts by inheriting from `Clonable` and following a few simple implementation guidelines.

## Developers: Implementation guide

/_Coming soon._/

## Users: Cloning guide

/_Coming soon._/
