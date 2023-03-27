// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.19;

import {Test721Enumerable} from "test/sudoswap/mocks/Test721Enumerable.sol";
import {IERC721Mintable} from "test/sudoswap/interfaces/IERC721Mintable.sol";
import {Configurable} from "test/sudoswap/mixins/Configurable.sol";

abstract contract UsingEnumerable is Configurable {
    function setup721() public override returns (IERC721Mintable) {
        return IERC721Mintable(address(new Test721Enumerable()));
    }
}
