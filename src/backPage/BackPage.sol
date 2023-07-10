// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Clone} from "solady/utils/Clone.sol";
import {Page} from "src/Page.sol";

contract BackPage is Clone, Page {
    // Fixed clone immutable arg byte offsets
    uint256 private constant IMMUTABLE_ARG_OFFSET_COLLECTION = 0;

    function collection() public pure override returns (address) {
        return _getArgAddress(IMMUTABLE_ARG_OFFSET_COLLECTION);
    }
}
