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

## Contracts: WERC721

The WERC721 contract is a partial implementation of the ERC721 interface with additional broadly-useful utility: call-batching and meta transactions.

WERC721 is partially compliant with the ERC721 standard for the sake of reducing friction with regards to developer adoption (i.e. any application which interacts with ERC721 and does not make use of the missing ERC721 interface can seamlessly integrate WERC721) and to reduce token transfer gas costs substantially.

The following items from the ERC721 interface are removed in WERC721:
```
event Approval(address indexed _owner, address indexed _approved, uint256 indexed _tokenId);

function balanceOf(address _owner) external view returns (uint256);

function safeTransferFrom(address _from, address _to, uint256 _tokenId, bytes data) external payable;

function safeTransferFrom(address _from, address _to, uint256 _tokenId) external payable;

function approve(address _approved, uint256 _tokenId) external payable;

function getApproved(uint256 _tokenId) external view returns (address);
```

The following operations below are removed from the `transferFrom` function, reducing gas costs. Below each operation are details about their gas costs, enabling the reader to better understand the gas savings from using WERC721 (resources are linked below for verifying the figures).

> NOTE: [Solmate's ERC721](https://github.com/transmissions11/solmate/blob/main/src/tokens/ERC721.sol) implementation will be used for comparison since the library is popular and the contracts are exceptionally-written in plain Solidity (generally easier to read). There may be implementations which the list below does not apply to (e.g. an ERC721 implementation which uses a loop to determine an account's token balance vs. maintaining a storage variable).
>
> For the sake of simplicity, EIP2930 is not considered.

- `SLOAD` for checking whether `msg.sender` is approved to transfer `tokenId`.
    - Incurs a 2,100 gas cost (cold access).
- `SSTORE` for decrementing the balance of `from`.
    - Incurs a 2,100 gas cost (cold access).
    - Incurs a 2,900 gas cost (slot started non-zero, pending change).
    - If the new balance of `from` is zero, results in a 4,800 gas refund.
    - Net gas cost = 200 or 5,000.
- `SSTORE` for incrementing the balance of `to` (we are assuming that `from` and `to` are not the same account).
    - Incurs a 2,100 gas cost (cold access).
    - If the original balance of `to` was zero, incurs a 20,000 gas cost.
    - Else incurs a 2,900 gas cost.
    - Net gas cost = 5,000 or 22,100.
- `SSTORE` for deleting the token approval.
    - If `msg.sender` did not have an approval for this token, incurs a 100 gas cost (no op).
    - Else incurs a 2,900 gas cost (slot started non-zero, pending change) and results in a 4,800 gas refund.
    - Net gas cost = -1,900 or 100.

Referring to the gas costs of the removed operations above, the gas savings from switching to `WERC721.transferFrom` ranges from 3,300 and 27,200 gas.

It's important to note that the act of wrapping ERC721 tokens costs gas and users should factor that into their decision-making when considering whether or not to use WERC721. For tokens that are transferred frequently, the gas savings will likely recoup the wrapping gas costs quickly.

Reference material:
- [Dynamic gas cost appendix by wolflo](https://github.com/wolflo/evm-opcodes/blob/main/gas.md).
- [EVM Codes](https://www.evm.codes/?fork=shanghai).

[WIP]

...

## Installation

The steps below assume that the code repo has already been cloned and the reader has navigated to the root of the project directory.

1. Install Foundry: https://book.getfoundry.sh/.
2. Run `forge i` to install project dependencies.
3. Run `forge test` to compile contracts and run tests.

## Audits

Coming soon.
