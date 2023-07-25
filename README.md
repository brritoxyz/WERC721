# WERC721

WERC721 (wrapped ERC721) tokens are redeemable extensions of their ERC721 counterparts with the following benefits:
- Significantly-reduced transfer gas costs;
- Native call-batching; and
- Meta transactions.

## Contracts: Overview

The project is comprised of two (2) key contracts:
- [WERC721Factory](https://github.com/jpvge/WERC721/blob/master/src/WERC721Factory.sol): Deploys WERC721 contracts against existing ERC721 contracts.
- [WERC721](https://github.com/jpvge/WERC721/blob/master/src/WERC721Factory.sol): Handles wrapping, unwrapping, and transfers for a single ERC721 contract.

## Installation

The steps below assume that the code repo has already been cloned and the reader has navigated to the root of the project directory.

1. Install Foundry: https://book.getfoundry.sh/.
2. Run `forge i` to install project dependencies.
3. Run `forge test` to compile contracts and run tests.

## Audits

Coming soon.
