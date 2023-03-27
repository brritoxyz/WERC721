// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.19;
import "openzeppelin/token/ERC721/ERC721.sol";

contract Test721 is ERC721 {
    constructor() ERC721("Test721", "T721") {}

    function mint(address to, uint256 id) public {
        _mint(to, id);
    }
}
