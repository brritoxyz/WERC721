# WERC721

WERC721 (wrapped ERC721) tokens are redeemable extensions of their ERC721 counterparts with the following benefits:
- Significantly-reduced transfer gas costs;
- Native call-batching; and
- Meta transactions.

## Contracts: Overview

The project is comprised of two (2) key contracts:
- [WERC721Factory](https://github.com/jpvge/WERC721/blob/master/src/WERC721Factory.sol): Deploys WERC721 contracts against existing ERC721 contracts.
- [WERC721](https://github.com/jpvge/WERC721/blob/master/src/WERC721Factory.sol): Handles wrapping, unwrapping, and transfers for a single ERC721 contract.

## Contracts: WERC721Factory

![WERC721Factory Diagram](https://github.com/jpvge/WERC721/blob/master/readme/WERC721FactoryDiagram.png?raw=true)

The WERC721Factory contract enables anyone to easily and cheaply deploy a WERC721 contract that is associated with a ERC721 contract (if one does not already exist - each ERC721 contract may only have one WERC721 contract) by employing the Clones With Immutable Args (CWIA) pattern.

The CWIA implementation contract is deployed by the WERC721Factory contract, and is admin-less, contains no `selfdestruct` calls, and does not delegate calls to any contracts other than itself (see [Multicallable#L46](https://github.com/Vectorized/solady/blob/2cfa231273fea6872c7cb70acfa134d2199aa7ea/src/utils/Multicallable.sol#L46)).

Reference material:
- [Clones with immutable args by wighawag, zefram.eth, Saw-mon & Natalie.](https://github.com/Saw-mon-and-Natalie/clones-with-immutable-args)
- [Minimal proxy library contract by vectorized.eth.](https://github.com/Vectorized/solady/blob/main/src/utils/LibClone.sol)

## Installation

The steps below assume that the code repo has already been cloned and the reader has navigated to the root of the project directory.

1. Install Foundry: https://book.getfoundry.sh/.
2. Run `forge i` to install project dependencies.
3. Run `forge test` to compile contracts and run tests.

## Audits

Coming soon.
