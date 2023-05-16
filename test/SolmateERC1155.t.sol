// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.20;

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import {DSInvariantTest} from "solmate/test/utils/DSInvariantTest.sol";
import {ERC1155NS, ERC1155TokenReceiver} from "src/base/ERC1155NS.sol";

contract MockERC1155 is ERC1155NS {
    function uri(
        uint256
    ) public pure virtual override returns (string memory) {}

    function mint(
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public {
        if (to == address(0)) revert("Zero");

        ownerOf[id] = to;

        emit TransferSingle(msg.sender, address(0), to, id, amount);

        require(
            to.code.length == 0
                ? to != address(0)
                : ERC1155TokenReceiver(to).onERC1155Received(
                    msg.sender,
                    address(0),
                    id,
                    1,
                    data
                ) == ERC1155TokenReceiver.onERC1155Received.selector,
            "UNSAFE_RECIPIENT"
        );
    }

    function batchMint(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public {
        uint256 idsLength = ids.length; // Saves MLOADs.

        require(idsLength == amounts.length, "LENGTH_MISMATCH");

        for (uint256 i = 0; i < idsLength; ) {
            ownerOf[ids[i]] = to;

            // An array can't have a total length
            // larger than the max uint256 value.
            unchecked {
                ++i;
            }
        }

        emit TransferBatch(msg.sender, address(0), to, ids, amounts);

        require(
            to.code.length == 0
                ? to != address(0)
                : ERC1155TokenReceiver(to).onERC1155BatchReceived(
                    msg.sender,
                    address(0),
                    ids,
                    amounts,
                    data
                ) == ERC1155TokenReceiver.onERC1155BatchReceived.selector,
            "UNSAFE_RECIPIENT"
        );
    }

    function burn(address, uint256 id, uint256) public virtual {
        if (ownerOf[id] == address(0)) revert("INSUFFICIENT_BALANCE");

        ownerOf[id] = address(0);
    }

    function batchBurn(
        address,
        uint256[] memory ids,
        uint256[] memory amounts
    ) public virtual {
        uint256 idsLength = ids.length; // Saves MLOADs.

        require(idsLength == amounts.length, "LENGTH_MISMATCH");

        for (uint256 i = 0; i < idsLength; ) {
            if (ownerOf[ids[i]] == address(0)) revert("INSUFFICIENT_BALANCE");

            ownerOf[ids[i]] = address(0);

            // An array can't have a total length
            // larger than the max uint256 value.
            unchecked {
                ++i;
            }
        }
    }
}

contract ERC1155Recipient is ERC1155TokenReceiver {
    address public operator;
    address public from;
    uint256 public id;
    uint256 public amount;
    bytes public mintData;

    function onERC1155Received(
        address _operator,
        address _from,
        uint256 _id,
        uint256 _amount,
        bytes calldata _data
    ) public override returns (bytes4) {
        operator = _operator;
        from = _from;
        id = _id;
        amount = _amount;
        mintData = _data;

        return ERC1155TokenReceiver.onERC1155Received.selector;
    }

    address public batchOperator;
    address public batchFrom;
    uint256[] internal _batchIds;
    uint256[] internal _batchAmounts;
    bytes public batchData;

    function batchIds() external view returns (uint256[] memory) {
        return _batchIds;
    }

    function batchAmounts() external view returns (uint256[] memory) {
        return _batchAmounts;
    }

    function onERC1155BatchReceived(
        address _operator,
        address _from,
        uint256[] calldata _ids,
        uint256[] calldata _amounts,
        bytes calldata _data
    ) external override returns (bytes4) {
        batchOperator = _operator;
        batchFrom = _from;
        _batchIds = _ids;
        _batchAmounts = _amounts;
        batchData = _data;

        return ERC1155TokenReceiver.onERC1155BatchReceived.selector;
    }
}

contract RevertingERC1155Recipient is ERC1155TokenReceiver {
    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) public pure override returns (bytes4) {
        revert(
            string(
                abi.encodePacked(
                    ERC1155TokenReceiver.onERC1155Received.selector
                )
            )
        );
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external pure override returns (bytes4) {
        revert(
            string(
                abi.encodePacked(
                    ERC1155TokenReceiver.onERC1155BatchReceived.selector
                )
            )
        );
    }
}

contract WrongReturnDataERC1155Recipient is ERC1155TokenReceiver {
    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) public pure override returns (bytes4) {
        return 0xCAFEBEEF;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external pure override returns (bytes4) {
        return 0xCAFEBEEF;
    }
}

contract NonERC1155Recipient {}

contract ERC1155Test is DSTestPlus, ERC1155TokenReceiver {
    MockERC1155 token;

    mapping(address => mapping(uint256 => uint256)) public userMintAmounts;
    mapping(address => mapping(uint256 => uint256))
        public userTransferOrBurnAmounts;

    function setUp() public {
        token = new MockERC1155();
    }

    function testMintToEOA() public {
        token.mint(address(0xBEEF), 1337, 1, "");

        assertEq(token.balanceOf(address(0xBEEF), 1337), 1);
    }

    function testBatchMintToEOA() public {
        uint256[] memory ids = new uint256[](5);
        ids[0] = 1337;
        ids[1] = 1338;
        ids[2] = 1339;
        ids[3] = 1340;
        ids[4] = 1341;

        uint256[] memory amounts = new uint256[](5);
        amounts[0] = 1;
        amounts[1] = 1;
        amounts[2] = 1;
        amounts[3] = 1;
        amounts[4] = 1;

        token.batchMint(address(0xBEEF), ids, amounts, "");

        assertEq(token.balanceOf(address(0xBEEF), 1337), 1);
        assertEq(token.balanceOf(address(0xBEEF), 1338), 1);
        assertEq(token.balanceOf(address(0xBEEF), 1339), 1);
        assertEq(token.balanceOf(address(0xBEEF), 1340), 1);
        assertEq(token.balanceOf(address(0xBEEF), 1341), 1);
    }

    function testBurn() public {
        token.mint(address(0xBEEF), 1337, 1, "");
        token.burn(address(0xBEEF), 1337, 1);

        assertEq(token.balanceOf(address(0xBEEF), 1337), 0);
    }

    function testBatchBurn() public {
        uint256[] memory ids = new uint256[](5);
        ids[0] = 1337;
        ids[1] = 1338;
        ids[2] = 1339;
        ids[3] = 1340;
        ids[4] = 1341;

        uint256[] memory mintAmounts = new uint256[](5);
        mintAmounts[0] = 100;
        mintAmounts[1] = 200;
        mintAmounts[2] = 300;
        mintAmounts[3] = 400;
        mintAmounts[4] = 500;

        uint256[] memory burnAmounts = new uint256[](5);
        burnAmounts[0] = 1;
        burnAmounts[1] = 1;
        burnAmounts[2] = 1;
        burnAmounts[3] = 1;
        burnAmounts[4] = 1;

        token.batchMint(address(0xBEEF), ids, mintAmounts, "");
        token.batchBurn(address(0xBEEF), ids, burnAmounts);

        assertEq(token.balanceOf(address(0xBEEF), 1337), 0);
        assertEq(token.balanceOf(address(0xBEEF), 1338), 0);
        assertEq(token.balanceOf(address(0xBEEF), 1339), 0);
        assertEq(token.balanceOf(address(0xBEEF), 1340), 0);
        assertEq(token.balanceOf(address(0xBEEF), 1341), 0);
    }

    function testApproveAll() public {
        token.setApprovalForAll(address(0xBEEF), true);

        assertTrue(token.isApprovedForAll(address(this), address(0xBEEF)));
    }

    function testSafeTransferFromToEOA() public {
        address from = address(0xABCD);

        token.mint(from, 1337, 1, "");

        hevm.prank(from);

        token.setApprovalForAll(address(this), true);
        token.safeTransferFrom(from, address(0xBEEF), 1337, 1, "");

        assertEq(token.balanceOf(address(0xBEEF), 1337), 1);
        assertEq(token.balanceOf(from, 1337), 0);
    }

    function testTransferFromToEOA() public {
        address from = address(0xABCD);

        token.mint(from, 1337, 1, "");

        hevm.prank(from);

        token.setApprovalForAll(address(this), true);
        token.transferFrom(from, address(0xBEEF), 1337);

        assertEq(token.balanceOf(address(0xBEEF), 1337), 1);
        assertEq(token.balanceOf(from, 1337), 0);
    }

    function testSafeTransferFromSelf() public {
        token.mint(address(this), 1337, 1, "");
        token.safeTransferFrom(address(this), address(0xBEEF), 1337, 1, "");

        assertEq(token.balanceOf(address(0xBEEF), 1337), 1);
        assertEq(token.balanceOf(address(this), 1337), 0);
    }

    function testTransferFromSelf() public {
        token.mint(address(this), 1337, 1, "");
        token.transferFrom(address(this), address(0xBEEF), 1337);

        assertEq(token.balanceOf(address(0xBEEF), 1337), 1);
        assertEq(token.balanceOf(address(this), 1337), 0);
    }

    function testSafeBatchTransferFromToEOA() public {
        address from = address(0xABCD);

        uint256[] memory ids = new uint256[](5);
        ids[0] = 1337;
        ids[1] = 1338;
        ids[2] = 1339;
        ids[3] = 1340;
        ids[4] = 1341;

        uint256[] memory mintAmounts = new uint256[](5);
        mintAmounts[0] = 1;
        mintAmounts[1] = 1;
        mintAmounts[2] = 1;
        mintAmounts[3] = 1;
        mintAmounts[4] = 1;

        uint256[] memory transferAmounts = new uint256[](5);
        transferAmounts[0] = 1;
        transferAmounts[1] = 1;
        transferAmounts[2] = 1;
        transferAmounts[3] = 1;
        transferAmounts[4] = 1;

        token.batchMint(from, ids, mintAmounts, "");

        hevm.prank(from);

        token.setApprovalForAll(address(this), true);
        token.safeBatchTransferFrom(
            from,
            address(0xBEEF),
            ids,
            transferAmounts,
            ""
        );

        assertEq(token.balanceOf(from, 1337), 0);
        assertEq(token.balanceOf(address(0xBEEF), 1337), 1);

        assertEq(token.balanceOf(from, 1338), 0);
        assertEq(token.balanceOf(address(0xBEEF), 1338), 1);

        assertEq(token.balanceOf(from, 1339), 0);
        assertEq(token.balanceOf(address(0xBEEF), 1339), 1);

        assertEq(token.balanceOf(from, 1340), 0);
        assertEq(token.balanceOf(address(0xBEEF), 1340), 1);

        assertEq(token.balanceOf(from, 1341), 0);
        assertEq(token.balanceOf(address(0xBEEF), 1341), 1);
    }

    function testBatchTransferFromToEOA() public {
        address from = address(0xABCD);

        uint256[] memory ids = new uint256[](5);
        ids[0] = 1337;
        ids[1] = 1338;
        ids[2] = 1339;
        ids[3] = 1340;
        ids[4] = 1341;

        uint256[] memory mintAmounts = new uint256[](5);
        mintAmounts[0] = 1;
        mintAmounts[1] = 1;
        mintAmounts[2] = 1;
        mintAmounts[3] = 1;
        mintAmounts[4] = 1;

        uint256[] memory transferAmounts = new uint256[](5);
        transferAmounts[0] = 1;
        transferAmounts[1] = 1;
        transferAmounts[2] = 1;
        transferAmounts[3] = 1;
        transferAmounts[4] = 1;

        token.batchMint(from, ids, mintAmounts, "");

        hevm.prank(from);

        token.setApprovalForAll(address(this), true);
        token.batchTransferFrom(from, address(0xBEEF), ids);

        assertEq(token.balanceOf(from, 1337), 0);
        assertEq(token.balanceOf(address(0xBEEF), 1337), 1);

        assertEq(token.balanceOf(from, 1338), 0);
        assertEq(token.balanceOf(address(0xBEEF), 1338), 1);

        assertEq(token.balanceOf(from, 1339), 0);
        assertEq(token.balanceOf(address(0xBEEF), 1339), 1);

        assertEq(token.balanceOf(from, 1340), 0);
        assertEq(token.balanceOf(address(0xBEEF), 1340), 1);

        assertEq(token.balanceOf(from, 1341), 0);
        assertEq(token.balanceOf(address(0xBEEF), 1341), 1);
    }

    function testSafeBatchTransferFromToERC1155Recipient() public {
        address from = address(0xABCD);

        ERC1155Recipient to = new ERC1155Recipient();

        uint256[] memory ids = new uint256[](5);
        ids[0] = 1337;
        ids[1] = 1338;
        ids[2] = 1339;
        ids[3] = 1340;
        ids[4] = 1341;

        uint256[] memory mintAmounts = new uint256[](5);
        mintAmounts[0] = 1;
        mintAmounts[1] = 1;
        mintAmounts[2] = 1;
        mintAmounts[3] = 1;
        mintAmounts[4] = 1;

        uint256[] memory transferAmounts = new uint256[](5);
        transferAmounts[0] = 1;
        transferAmounts[1] = 1;
        transferAmounts[2] = 1;
        transferAmounts[3] = 1;
        transferAmounts[4] = 1;

        token.batchMint(from, ids, mintAmounts, "");

        hevm.prank(from);

        token.setApprovalForAll(address(this), true);
        token.safeBatchTransferFrom(
            from,
            address(to),
            ids,
            transferAmounts,
            "testing 123"
        );

        assertEq(to.batchOperator(), address(this));
        assertEq(to.batchFrom(), from);
        assertUintArrayEq(to.batchIds(), ids);
        assertUintArrayEq(to.batchAmounts(), transferAmounts);
        assertBytesEq(to.batchData(), "testing 123");

        assertEq(token.balanceOf(from, 1337), 0);
        assertEq(token.balanceOf(address(to), 1337), 1);

        assertEq(token.balanceOf(from, 1338), 0);
        assertEq(token.balanceOf(address(to), 1338), 1);

        assertEq(token.balanceOf(from, 1339), 0);
        assertEq(token.balanceOf(address(to), 1339), 1);

        assertEq(token.balanceOf(from, 1340), 0);
        assertEq(token.balanceOf(address(to), 1340), 1);

        assertEq(token.balanceOf(from, 1341), 0);
        assertEq(token.balanceOf(address(to), 1341), 1);
    }

    function testBatchTransferFromToERC1155Recipient() public {
        address from = address(0xABCD);

        ERC1155Recipient to = new ERC1155Recipient();

        uint256[] memory ids = new uint256[](5);
        ids[0] = 1337;
        ids[1] = 1338;
        ids[2] = 1339;
        ids[3] = 1340;
        ids[4] = 1341;

        uint256[] memory mintAmounts = new uint256[](5);
        mintAmounts[0] = 1;
        mintAmounts[1] = 1;
        mintAmounts[2] = 1;
        mintAmounts[3] = 1;
        mintAmounts[4] = 1;

        uint256[] memory transferAmounts = new uint256[](5);
        transferAmounts[0] = 1;
        transferAmounts[1] = 1;
        transferAmounts[2] = 1;
        transferAmounts[3] = 1;
        transferAmounts[4] = 1;

        token.batchMint(from, ids, mintAmounts, "");

        hevm.prank(from);

        token.setApprovalForAll(address(this), true);
        token.batchTransferFrom(from, address(to), ids);

        assertEq(token.balanceOf(from, 1337), 0);
        assertEq(token.balanceOf(address(to), 1337), 1);

        assertEq(token.balanceOf(from, 1338), 0);
        assertEq(token.balanceOf(address(to), 1338), 1);

        assertEq(token.balanceOf(from, 1339), 0);
        assertEq(token.balanceOf(address(to), 1339), 1);

        assertEq(token.balanceOf(from, 1340), 0);
        assertEq(token.balanceOf(address(to), 1340), 1);

        assertEq(token.balanceOf(from, 1341), 0);
        assertEq(token.balanceOf(address(to), 1341), 1);
    }

    function testBatchBalanceOf() public {
        address[] memory tos = new address[](5);
        tos[0] = address(0xBEEF);
        tos[1] = address(0xCAFE);
        tos[2] = address(0xFACE);
        tos[3] = address(0xDEAD);
        tos[4] = address(0xFEED);

        uint256[] memory ids = new uint256[](5);
        ids[0] = 1337;
        ids[1] = 1338;
        ids[2] = 1339;
        ids[3] = 1340;
        ids[4] = 1341;

        token.mint(address(0xBEEF), 1337, 1, "");
        token.mint(address(0xCAFE), 1338, 1, "");
        token.mint(address(0xFACE), 1339, 1, "");
        token.mint(address(0xDEAD), 1340, 1, "");
        token.mint(address(0xFEED), 1341, 1, "");

        uint256[] memory balances = token.balanceOfBatch(tos, ids);

        assertEq(balances[0], 1);
        assertEq(balances[1], 1);
        assertEq(balances[2], 1);
        assertEq(balances[3], 1);
        assertEq(balances[4], 1);
    }

    function testFailSafeTransferFromInsufficientBalance() public {
        address from = address(0xABCD);

        token.mint(from, 1337, 1, "");

        hevm.prank(from);
        token.setApprovalForAll(address(this), true);

        // Call twice to trigger "insufficient balance" error since transfer amounts are fixed at 1
        token.safeTransferFrom(from, address(0xBEEF), 1337, 1, "");
        token.safeTransferFrom(from, address(0xBEEF), 1337, 1, "");
    }

    function testFailTransferFromInsufficientBalance() public {
        address from = address(0xABCD);

        token.mint(from, 1337, 1, "");

        hevm.prank(from);
        token.setApprovalForAll(address(this), true);

        // Call twice to trigger "insufficient balance" error since transfer amounts are fixed at 1
        token.transferFrom(from, address(0xBEEF), 1337);
        token.transferFrom(from, address(0xBEEF), 1337);
    }

    function testFailSafeTransferFromSelfInsufficientBalance() public {
        token.mint(address(this), 1337, 1, "");
        token.safeTransferFrom(address(this), address(0xBEEF), 1337, 1, "");
        token.safeTransferFrom(address(this), address(0xBEEF), 1337, 1, "");
    }

    function testFailTransferFromSelfInsufficientBalance() public {
        token.mint(address(this), 1337, 1, "");
        token.transferFrom(address(this), address(0xBEEF), 1337);
        token.transferFrom(address(this), address(0xBEEF), 1337);
    }

    function testFailSafeTransferFromToZero() public {
        token.mint(address(this), 1337, 1, "");
        token.safeTransferFrom(address(this), address(0), 1337, 1, "");
    }

    function testFailTransferFromToZero() public {
        token.mint(address(this), 1337, 1, "");
        token.transferFrom(address(this), address(0), 1337);
    }

    function testFailSafeTransferFromToNonERC155Recipient() public {
        token.mint(address(this), 1337, 1, "");
        token.safeTransferFrom(
            address(this),
            address(new NonERC1155Recipient()),
            1337,
            1,
            ""
        );
    }

    function testFailSafeTransferFromToRevertingERC1155Recipient() public {
        token.mint(address(this), 1337, 1, "");
        token.safeTransferFrom(
            address(this),
            address(new RevertingERC1155Recipient()),
            1337,
            1,
            ""
        );
    }

    function testFailSafeTransferFromToWrongReturnDataERC1155Recipient()
        public
    {
        token.mint(address(this), 1337, 1, "");
        token.safeTransferFrom(
            address(this),
            address(new WrongReturnDataERC1155Recipient()),
            1337,
            1,
            ""
        );
    }

    function testFailSafeBatchTransferInsufficientBalance() public {
        address from = address(0xABCD);

        uint256[] memory ids = new uint256[](5);
        ids[0] = 1337;
        ids[1] = 1338;
        ids[2] = 1339;
        ids[3] = 1340;
        ids[4] = 1341;

        uint256[] memory mintAmounts = new uint256[](5);
        mintAmounts[0] = 1;
        mintAmounts[1] = 1;
        mintAmounts[2] = 1;
        mintAmounts[3] = 1;
        mintAmounts[4] = 1;

        uint256[] memory transferAmounts = new uint256[](5);
        transferAmounts[0] = 1;
        transferAmounts[1] = 1;
        transferAmounts[2] = 1;
        transferAmounts[3] = 1;
        transferAmounts[4] = 1;

        token.batchMint(from, ids, mintAmounts, "");

        hevm.prank(from);

        token.setApprovalForAll(address(this), true);
        token.safeBatchTransferFrom(
            from,
            address(0xBEEF),
            ids,
            transferAmounts,
            ""
        );
        token.safeBatchTransferFrom(
            from,
            address(0xBEEF),
            ids,
            transferAmounts,
            ""
        );
    }

    function testFailBatchTransferInsufficientBalance() public {
        address from = address(0xABCD);

        uint256[] memory ids = new uint256[](5);
        ids[0] = 1337;
        ids[1] = 1338;
        ids[2] = 1339;
        ids[3] = 1340;
        ids[4] = 1341;

        uint256[] memory mintAmounts = new uint256[](5);
        mintAmounts[0] = 1;
        mintAmounts[1] = 1;
        mintAmounts[2] = 1;
        mintAmounts[3] = 1;
        mintAmounts[4] = 1;

        uint256[] memory transferAmounts = new uint256[](5);
        transferAmounts[0] = 1;
        transferAmounts[1] = 1;
        transferAmounts[2] = 1;
        transferAmounts[3] = 1;
        transferAmounts[4] = 1;

        token.batchMint(from, ids, mintAmounts, "");

        hevm.prank(from);

        token.setApprovalForAll(address(this), true);
        token.batchTransferFrom(from, address(0xBEEF), ids);
        token.batchTransferFrom(from, address(0xBEEF), ids);
    }

    function testFailSafeBatchTransferFromToZero() public {
        address from = address(0xABCD);

        uint256[] memory ids = new uint256[](5);
        ids[0] = 1337;
        ids[1] = 1338;
        ids[2] = 1339;
        ids[3] = 1340;
        ids[4] = 1341;

        uint256[] memory mintAmounts = new uint256[](5);
        mintAmounts[0] = 1;
        mintAmounts[1] = 1;
        mintAmounts[2] = 1;
        mintAmounts[3] = 1;
        mintAmounts[4] = 1;

        uint256[] memory transferAmounts = new uint256[](5);
        transferAmounts[0] = 1;
        transferAmounts[1] = 1;
        transferAmounts[2] = 1;
        transferAmounts[3] = 1;
        transferAmounts[4] = 1;

        token.batchMint(from, ids, mintAmounts, "");

        hevm.prank(from);

        token.setApprovalForAll(address(this), true);
        token.safeBatchTransferFrom(from, address(0), ids, transferAmounts, "");
    }

    function testFailBatchTransferFromToZero() public {
        address from = address(0xABCD);

        uint256[] memory ids = new uint256[](5);
        ids[0] = 1337;
        ids[1] = 1338;
        ids[2] = 1339;
        ids[3] = 1340;
        ids[4] = 1341;

        uint256[] memory mintAmounts = new uint256[](5);
        mintAmounts[0] = 1;
        mintAmounts[1] = 1;
        mintAmounts[2] = 1;
        mintAmounts[3] = 1;
        mintAmounts[4] = 1;

        uint256[] memory transferAmounts = new uint256[](5);
        transferAmounts[0] = 1;
        transferAmounts[1] = 1;
        transferAmounts[2] = 1;
        transferAmounts[3] = 1;
        transferAmounts[4] = 1;

        token.batchMint(from, ids, mintAmounts, "");

        hevm.prank(from);

        token.setApprovalForAll(address(this), true);
        token.batchTransferFrom(from, address(0), ids);
    }

    function testFailSafeBatchTransferFromToNonERC1155Recipient() public {
        address from = address(0xABCD);

        uint256[] memory ids = new uint256[](5);
        ids[0] = 1337;
        ids[1] = 1338;
        ids[2] = 1339;
        ids[3] = 1340;
        ids[4] = 1341;

        uint256[] memory mintAmounts = new uint256[](5);
        mintAmounts[0] = 1;
        mintAmounts[1] = 1;
        mintAmounts[2] = 1;
        mintAmounts[3] = 1;
        mintAmounts[4] = 1;

        uint256[] memory transferAmounts = new uint256[](5);
        transferAmounts[0] = 1;
        transferAmounts[1] = 1;
        transferAmounts[2] = 1;
        transferAmounts[3] = 1;
        transferAmounts[4] = 1;

        token.batchMint(from, ids, mintAmounts, "");

        hevm.prank(from);

        token.setApprovalForAll(address(this), true);
        token.safeBatchTransferFrom(
            from,
            address(new NonERC1155Recipient()),
            ids,
            transferAmounts,
            ""
        );
    }

    function testFailSafeBatchTransferFromToRevertingERC1155Recipient() public {
        address from = address(0xABCD);

        uint256[] memory ids = new uint256[](5);
        ids[0] = 1337;
        ids[1] = 1338;
        ids[2] = 1339;
        ids[3] = 1340;
        ids[4] = 1341;

        uint256[] memory mintAmounts = new uint256[](5);
        mintAmounts[0] = 1;
        mintAmounts[1] = 1;
        mintAmounts[2] = 1;
        mintAmounts[3] = 1;
        mintAmounts[4] = 1;

        uint256[] memory transferAmounts = new uint256[](5);
        transferAmounts[0] = 1;
        transferAmounts[1] = 1;
        transferAmounts[2] = 1;
        transferAmounts[3] = 1;
        transferAmounts[4] = 1;

        token.batchMint(from, ids, mintAmounts, "");

        hevm.prank(from);

        token.setApprovalForAll(address(this), true);
        token.safeBatchTransferFrom(
            from,
            address(new RevertingERC1155Recipient()),
            ids,
            transferAmounts,
            ""
        );
    }

    function testFailSafeBatchTransferFromToWrongReturnDataERC1155Recipient()
        public
    {
        address from = address(0xABCD);

        uint256[] memory ids = new uint256[](5);
        ids[0] = 1337;
        ids[1] = 1338;
        ids[2] = 1339;
        ids[3] = 1340;
        ids[4] = 1341;

        uint256[] memory mintAmounts = new uint256[](5);
        mintAmounts[0] = 1;
        mintAmounts[1] = 1;
        mintAmounts[2] = 1;
        mintAmounts[3] = 1;
        mintAmounts[4] = 1;

        uint256[] memory transferAmounts = new uint256[](5);
        transferAmounts[0] = 1;
        transferAmounts[1] = 1;
        transferAmounts[2] = 1;
        transferAmounts[3] = 1;
        transferAmounts[4] = 1;

        token.batchMint(from, ids, mintAmounts, "");

        hevm.prank(from);

        token.setApprovalForAll(address(this), true);
        token.safeBatchTransferFrom(
            from,
            address(new WrongReturnDataERC1155Recipient()),
            ids,
            transferAmounts,
            ""
        );
    }

    function testFailBalanceOfBatchWithArrayMismatch() public view {
        address[] memory tos = new address[](5);
        tos[0] = address(0xBEEF);
        tos[1] = address(0xCAFE);
        tos[2] = address(0xFACE);
        tos[3] = address(0xDEAD);
        tos[4] = address(0xFEED);

        uint256[] memory ids = new uint256[](4);
        ids[0] = 1337;
        ids[1] = 1338;
        ids[2] = 1339;
        ids[3] = 1340;

        token.balanceOfBatch(tos, ids);
    }

    function testApproveAll(address to, bool approved) public {
        token.setApprovalForAll(to, approved);

        assertBoolEq(token.isApprovedForAll(address(this), to), approved);
    }

    function testSafeTransferFromToEOA(
        address to,
        uint256 id,
        bytes memory mintData,
        bytes memory transferData
    ) public {
        address from = address(0xABCD);
        uint256 mintAmount = 1;
        uint256 transferAmount = 1;

        if (to == address(0)) to = address(0xBEEF);
        if (uint256(uint160(to)) <= 18 || to.code.length > 0) return;

        token.mint(from, id, mintAmount, mintData);

        hevm.prank(from);

        token.setApprovalForAll(address(this), true);
        token.safeTransferFrom(from, to, id, transferAmount, transferData);

        if (to == from) {
            assertEq(token.balanceOf(to, id), mintAmount);
        } else {
            assertEq(token.balanceOf(to, id), 1);
            assertEq(token.balanceOf(from, id), 0);
        }
    }

    function testTransferFromToEOA(
        address to,
        uint256 id,
        bytes memory mintData
    ) public {
        address from = address(0xABCD);
        uint256 mintAmount = 1;

        if (to == address(0)) to = address(0xBEEF);
        if (uint256(uint160(to)) <= 18 || to.code.length > 0) return;

        token.mint(from, id, mintAmount, mintData);

        hevm.prank(from);

        token.setApprovalForAll(address(this), true);
        token.transferFrom(from, to, id);

        if (to == from) {
            assertEq(token.balanceOf(to, id), mintAmount);
        } else {
            assertEq(token.balanceOf(to, id), 1);
            assertEq(token.balanceOf(from, id), 0);
        }
    }

    function testSafeTransferFromToERC1155Recipient(
        uint256 id,
        bytes memory mintData,
        bytes memory transferData
    ) public {
        ERC1155Recipient to = new ERC1155Recipient();
        address from = address(0xABCD);
        uint256 mintAmount = 1;
        uint256 transferAmount = 1;

        token.mint(from, id, mintAmount, mintData);

        hevm.prank(from);

        token.setApprovalForAll(address(this), true);
        token.safeTransferFrom(
            from,
            address(to),
            id,
            transferAmount,
            transferData
        );

        assertEq(to.operator(), address(this));
        assertEq(to.from(), from);
        assertEq(to.id(), id);
        assertBytesEq(to.mintData(), transferData);
        assertEq(token.balanceOf(address(to), id), 1);
        assertEq(token.balanceOf(from, id), 0);
    }

    function testTransferFromToERC1155Recipient(
        uint256 id,
        bytes memory mintData
    ) public {
        ERC1155Recipient to = new ERC1155Recipient();
        address from = address(0xABCD);
        uint256 mintAmount = 1;

        token.mint(from, id, mintAmount, mintData);

        hevm.prank(from);

        token.setApprovalForAll(address(this), true);
        token.transferFrom(from, address(to), id);

        assertEq(token.balanceOf(address(to), id), 1);
        assertEq(token.balanceOf(from, id), 0);
    }

    function testSafeTransferFromSelf(
        address to,
        uint256 id,
        bytes memory mintData,
        bytes memory transferData
    ) public {
        uint256 mintAmount = 1;
        uint256 transferAmount = 1;

        if (to == address(0)) to = address(0xBEEF);
        if (uint256(uint160(to)) <= 18 || to.code.length > 0) return;

        token.mint(address(this), id, mintAmount, mintData);
        token.safeTransferFrom(
            address(this),
            to,
            id,
            transferAmount,
            transferData
        );

        assertEq(token.balanceOf(to, id), 1);
        assertEq(token.balanceOf(address(this), id), 0);
    }

    function testTransferFromSelf(
        address to,
        uint256 id,
        bytes memory mintData
    ) public {
        uint256 mintAmount = 1;

        if (to == address(0)) to = address(0xBEEF);
        if (uint256(uint160(to)) <= 18 || to.code.length > 0) return;

        token.mint(address(this), id, mintAmount, mintData);
        token.transferFrom(address(this), to, id);

        assertEq(token.balanceOf(to, id), 1);
        assertEq(token.balanceOf(address(this), id), 0);
    }

    function testSafeBatchTransferFromToEOA(
        address to,
        bytes memory mintData,
        bytes memory transferData
    ) public {
        address from = address(0xABCD);
        uint256[] memory ids = new uint256[](10);
        uint256[] memory mintAmounts = new uint256[](ids.length);
        uint256[] memory transferAmounts = new uint256[](ids.length);

        unchecked {
            for (uint256 i; i < ids.length; ++i) {
                ids[i] = i;
                mintAmounts[i] = 1;
                transferAmounts[i] = 1;
            }
        }

        if (to == address(0)) to = address(0xBEEF);
        if (uint256(uint160(to)) <= 18 || to.code.length > 0) return;

        token.batchMint(from, ids, mintAmounts, mintData);

        hevm.prank(from);

        token.setApprovalForAll(address(this), true);
        token.safeBatchTransferFrom(
            from,
            to,
            ids,
            transferAmounts,
            transferData
        );

        unchecked {
            for (uint256 i = 0; i < ids.length; i++) {
                uint256 id = ids[i];

                assertEq(token.balanceOf(address(to), id), 1);
                assertEq(token.balanceOf(from, id), 0);
            }
        }
    }

    function testBatchTransferFromToEOA(
        address to,
        bytes memory mintData
    ) public {
        address from = address(0xABCD);
        uint256[] memory ids = new uint256[](10);
        uint256[] memory mintAmounts = new uint256[](ids.length);

        unchecked {
            for (uint256 i; i < ids.length; ++i) {
                ids[i] = i;
                mintAmounts[i] = 1;
            }
        }

        if (to == address(0)) to = address(0xBEEF);
        if (uint256(uint160(to)) <= 18 || to.code.length > 0) return;

        token.batchMint(from, ids, mintAmounts, mintData);

        hevm.prank(from);

        token.setApprovalForAll(address(this), true);
        token.batchTransferFrom(from, to, ids);

        unchecked {
            for (uint256 i = 0; i < ids.length; i++) {
                uint256 id = ids[i];

                assertEq(token.balanceOf(address(to), id), 1);
                assertEq(token.balanceOf(from, id), 0);
            }
        }
    }

    function testSafeBatchTransferFromToERC1155Recipient(
        bytes memory mintData,
        bytes memory transferData
    ) public {
        address from = address(0xABCD);
        uint256[] memory ids = new uint256[](10);
        uint256[] memory mintAmounts = new uint256[](ids.length);
        uint256[] memory transferAmounts = new uint256[](ids.length);

        unchecked {
            for (uint256 i; i < ids.length; ++i) {
                ids[i] = i;
                mintAmounts[i] = 1;
                transferAmounts[i] = 1;
            }
        }

        ERC1155Recipient to = new ERC1155Recipient();

        token.batchMint(from, ids, mintAmounts, mintData);

        hevm.prank(from);

        token.setApprovalForAll(address(this), true);
        token.safeBatchTransferFrom(
            from,
            address(to),
            ids,
            transferAmounts,
            transferData
        );

        assertEq(to.batchOperator(), address(this));
        assertEq(to.batchFrom(), from);
        assertUintArrayEq(to.batchIds(), ids);
        assertUintArrayEq(to.batchAmounts(), transferAmounts);
        assertBytesEq(to.batchData(), transferData);

        unchecked {
            for (uint256 i = 0; i < ids.length; i++) {
                uint256 id = ids[i];

                assertEq(token.balanceOf(address(to), id), 1);
                assertEq(token.balanceOf(from, id), 0);
            }
        }
    }

    function testBatchTransferFromToERC1155Recipient(
        bytes memory mintData
    ) public {
        address from = address(0xABCD);
        uint256[] memory ids = new uint256[](10);
        uint256[] memory mintAmounts = new uint256[](ids.length);
        uint256[] memory transferAmounts = new uint256[](ids.length);

        unchecked {
            for (uint256 i; i < ids.length; ++i) {
                ids[i] = i;
                mintAmounts[i] = 1;
                transferAmounts[i] = 1;
            }
        }

        ERC1155Recipient to = new ERC1155Recipient();

        token.batchMint(from, ids, mintAmounts, mintData);

        hevm.prank(from);

        token.setApprovalForAll(address(this), true);
        token.batchTransferFrom(from, address(to), ids);

        unchecked {
            for (uint256 i = 0; i < ids.length; i++) {
                uint256 id = ids[i];

                assertEq(token.balanceOf(address(to), id), 1);
                assertEq(token.balanceOf(from, id), 0);
            }
        }
    }

    function testBatchBalanceOf(bytes memory mintData) public {
        address[] memory tos = new address[](10);
        uint256[] memory ids = new uint256[](tos.length);

        unchecked {
            for (uint256 i; i < ids.length; ++i) {
                tos[i] = address(uint160(i + 1));
                ids[i] = i;

                token.mint(tos[i], i, 1, mintData);
            }
        }

        uint256[] memory balances = token.balanceOfBatch(tos, ids);

        unchecked {
            for (uint256 i = 0; i < tos.length; i++) {
                assertEq(balances[i], token.balanceOf(tos[i], ids[i]));
            }
        }
    }

    function testFailSafeTransferFromInsufficientBalance(
        address to,
        uint256 id,
        bytes memory mintData,
        bytes memory transferData
    ) public {
        address from = address(0xABCD);
        uint256 mintAmount = 1;
        uint256 transferAmount = 1;

        token.mint(from, id, mintAmount, mintData);

        hevm.prank(from);

        token.setApprovalForAll(address(this), true);
        token.safeTransferFrom(from, to, id, transferAmount, transferData);
        token.safeTransferFrom(from, to, id, transferAmount, transferData);
    }

    function testFailTransferFromInsufficientBalance(
        address to,
        uint256 id,
        bytes memory mintData
    ) public {
        address from = address(0xABCD);
        uint256 mintAmount = 1;

        token.mint(from, id, mintAmount, mintData);

        hevm.prank(from);

        token.setApprovalForAll(address(this), true);
        token.transferFrom(from, to, id);
        token.transferFrom(from, to, id);
    }

    function testFailSafeTransferFromSelfInsufficientBalance(
        address to,
        uint256 id,
        bytes memory mintData,
        bytes memory transferData
    ) public {
        uint256 mintAmount = 1;
        uint256 transferAmount = 1;

        token.mint(address(this), id, mintAmount, mintData);
        token.safeTransferFrom(
            address(this),
            to,
            id,
            transferAmount,
            transferData
        );
        token.safeTransferFrom(
            address(this),
            to,
            id,
            transferAmount,
            transferData
        );
    }

    function testFailTransferFromSelfInsufficientBalance(
        address to,
        uint256 id,
        bytes memory mintData
    ) public {
        uint256 mintAmount = 1;

        token.mint(address(this), id, mintAmount, mintData);
        token.transferFrom(address(this), to, id);
        token.transferFrom(address(this), to, id);
    }

    function testFailSafeTransferFromToZero(
        uint256 id,
        bytes memory mintData,
        bytes memory transferData
    ) public {
        uint256 mintAmount = 1;
        uint256 transferAmount = 1;

        token.mint(address(this), id, mintAmount, mintData);
        token.safeTransferFrom(
            address(this),
            address(0),
            id,
            transferAmount,
            transferData
        );
    }

    function testFailTransferFromToZero(
        uint256 id,
        bytes memory mintData
    ) public {
        uint256 mintAmount = 1;

        token.mint(address(this), id, mintAmount, mintData);
        token.transferFrom(address(this), address(0), id);
    }

    function testFailSafeTransferFromToNonERC155Recipient(
        uint256 id,
        bytes memory mintData,
        bytes memory transferData
    ) public {
        uint256 mintAmount = 1;
        uint256 transferAmount = 1;

        token.mint(address(this), id, mintAmount, mintData);
        token.safeTransferFrom(
            address(this),
            address(new NonERC1155Recipient()),
            id,
            transferAmount,
            transferData
        );
    }

    function testFailSafeTransferFromToRevertingERC1155Recipient(
        uint256 id,
        bytes memory mintData,
        bytes memory transferData
    ) public {
        uint256 mintAmount = 1;
        uint256 transferAmount = 1;

        token.mint(address(this), id, mintAmount, mintData);
        token.safeTransferFrom(
            address(this),
            address(new RevertingERC1155Recipient()),
            id,
            transferAmount,
            transferData
        );
    }

    function testFailSafeTransferFromToWrongReturnDataERC1155Recipient(
        uint256 id,
        bytes memory mintData,
        bytes memory transferData
    ) public {
        uint256 mintAmount = 1;
        uint256 transferAmount = 1;

        token.mint(address(this), id, mintAmount, mintData);
        token.safeTransferFrom(
            address(this),
            address(new WrongReturnDataERC1155Recipient()),
            id,
            transferAmount,
            transferData
        );
    }

    function testFailSafeBatchTransferInsufficientBalance(
        address to,
        bytes memory mintData,
        bytes memory transferData
    ) public {
        uint256[] memory ids = new uint256[](10);
        uint256[] memory mintAmounts = new uint256[](ids.length);
        uint256[] memory transferAmounts = new uint256[](ids.length);

        unchecked {
            for (uint256 i; i < ids.length; ++i) {
                ids[i] = i;
                mintAmounts[i] = 1;
                transferAmounts[i] = 1;
            }
        }

        address from = address(0xABCD);

        token.batchMint(from, ids, mintAmounts, mintData);

        hevm.prank(from);

        token.setApprovalForAll(address(this), true);
        token.safeBatchTransferFrom(
            from,
            to,
            ids,
            transferAmounts,
            transferData
        );
        token.safeBatchTransferFrom(
            from,
            to,
            ids,
            transferAmounts,
            transferData
        );
    }

    function testFailBatchTransferInsufficientBalance(
        address to,
        bytes memory mintData
    ) public {
        uint256[] memory ids = new uint256[](10);
        uint256[] memory mintAmounts = new uint256[](ids.length);

        unchecked {
            for (uint256 i; i < ids.length; ++i) {
                ids[i] = i;
                mintAmounts[i] = 1;
            }
        }

        address from = address(0xABCD);

        token.batchMint(from, ids, mintAmounts, mintData);

        hevm.prank(from);

        token.setApprovalForAll(address(this), true);
        token.batchTransferFrom(from, to, ids);
        token.batchTransferFrom(from, to, ids);
    }

    function testFailSafeBatchTransferFromToZero(
        bytes memory mintData,
        bytes memory transferData
    ) public {
        address from = address(0xABCD);
        uint256[] memory ids = new uint256[](10);
        uint256[] memory mintAmounts = new uint256[](ids.length);
        uint256[] memory transferAmounts = new uint256[](ids.length);

        unchecked {
            for (uint256 i; i < ids.length; ++i) {
                ids[i] = i;
                mintAmounts[i] = 1;
                transferAmounts[i] = 1;
            }
        }

        token.batchMint(from, ids, mintAmounts, mintData);

        hevm.prank(from);

        token.setApprovalForAll(address(this), true);
        token.safeBatchTransferFrom(
            from,
            address(0),
            ids,
            transferAmounts,
            transferData
        );
    }

    function testFailBatchTransferFromToZero(bytes memory mintData) public {
        address from = address(0xABCD);
        uint256[] memory ids = new uint256[](10);
        uint256[] memory mintAmounts = new uint256[](ids.length);

        unchecked {
            for (uint256 i; i < ids.length; ++i) {
                ids[i] = i;
                mintAmounts[i] = 1;
            }
        }

        token.batchMint(from, ids, mintAmounts, mintData);

        hevm.prank(from);

        token.setApprovalForAll(address(this), true);
        token.batchTransferFrom(from, address(0), ids);
    }

    function testFailSafeBatchTransferFromToNonERC1155Recipient(
        bytes memory mintData,
        bytes memory transferData
    ) public {
        address from = address(0xABCD);
        uint256[] memory ids = new uint256[](10);
        uint256[] memory mintAmounts = new uint256[](ids.length);
        uint256[] memory transferAmounts = new uint256[](ids.length);

        unchecked {
            for (uint256 i; i < ids.length; ++i) {
                ids[i] = i;
                mintAmounts[i] = 1;
                transferAmounts[i] = 1;
            }
        }

        token.batchMint(from, ids, mintAmounts, mintData);

        hevm.prank(from);
        token.setApprovalForAll(address(this), true);

        token.safeBatchTransferFrom(
            from,
            address(new NonERC1155Recipient()),
            ids,
            transferAmounts,
            transferData
        );
    }

    function testFailSafeBatchTransferFromToRevertingERC1155Recipient(
        bytes memory mintData,
        bytes memory transferData
    ) public {
        address from = address(0xABCD);
        uint256[] memory ids = new uint256[](10);
        uint256[] memory mintAmounts = new uint256[](ids.length);
        uint256[] memory transferAmounts = new uint256[](ids.length);

        unchecked {
            for (uint256 i; i < ids.length; ++i) {
                ids[i] = i;
                mintAmounts[i] = 1;
                transferAmounts[i] = 1;
            }
        }

        token.batchMint(from, ids, mintAmounts, mintData);

        hevm.prank(from);

        token.setApprovalForAll(address(this), true);
        token.safeBatchTransferFrom(
            from,
            address(new RevertingERC1155Recipient()),
            ids,
            transferAmounts,
            transferData
        );
    }

    function testFailSafeBatchTransferFromToWrongReturnDataERC1155Recipient(
        bytes memory mintData,
        bytes memory transferData
    ) public {
        address from = address(0xABCD);
        uint256[] memory ids = new uint256[](10);
        uint256[] memory mintAmounts = new uint256[](ids.length);
        uint256[] memory transferAmounts = new uint256[](ids.length);

        unchecked {
            for (uint256 i; i < ids.length; ++i) {
                ids[i] = i;
                mintAmounts[i] = 1;
                transferAmounts[i] = 1;
            }
        }

        token.batchMint(from, ids, mintAmounts, mintData);

        hevm.prank(from);

        token.setApprovalForAll(address(this), true);
        token.safeBatchTransferFrom(
            from,
            address(new WrongReturnDataERC1155Recipient()),
            ids,
            transferAmounts,
            transferData
        );
    }

    function testFailSafeBatchTransferFromWithArrayLengthMismatch(
        address to,
        bytes memory mintData,
        bytes memory transferData
    ) public {
        address from = address(0xABCD);
        uint256[] memory ids = new uint256[](10);
        uint256[] memory mintAmounts = new uint256[](ids.length);
        uint256[] memory transferAmounts = new uint256[](ids.length);

        unchecked {
            for (uint256 i; i < ids.length; ++i) {
                ids[i] = i;
                mintAmounts[i] = 1;
                transferAmounts[i] = 1;
            }
        }

        if (ids.length == transferAmounts.length) revert();

        token.batchMint(from, ids, mintAmounts, mintData);

        hevm.prank(from);

        token.setApprovalForAll(address(this), true);
        token.safeBatchTransferFrom(
            from,
            to,
            ids,
            transferAmounts,
            transferData
        );
    }
}
