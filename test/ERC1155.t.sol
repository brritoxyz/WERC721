// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import {DSInvariantTest} from "solmate/test/utils/DSInvariantTest.sol";
import {ERC1155, ERC1155TokenReceiver} from "src/base/MoonERC1155.sol";

// Solmate ERC1155 tests applied to MoonERC1155.sol
// Original: https://raw.githubusercontent.com/transmissions11/solmate/main/src/test/ERC1155.t.sol
contract MockERC1155 is ERC1155 {
    function uri(
        uint256
    ) public pure virtual override returns (string memory) {}

    function mint(
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public virtual {
        _mint(to, id, amount, data);
    }

    function batchMint(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public virtual {
        _batchMint(to, ids, amounts, data);
    }

    function burn(address from, uint256 id, uint256 amount) public virtual {
        _burn(from, id, amount);
    }

    function batchBurn(
        address from,
        uint256[] memory ids,
        uint256[] memory amounts
    ) public virtual {
        _batchBurn(from, ids, amounts);
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

    function testMintToERC1155Recipient() public {
        ERC1155Recipient to = new ERC1155Recipient();

        token.mint(address(to), 1337, 1, "testing 123");

        assertEq(token.balanceOf(address(to), 1337), 1);

        assertEq(to.operator(), address(this));
        assertEq(to.from(), address(0));
        assertEq(to.id(), 1337);
        assertBytesEq(to.mintData(), "testing 123");
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

    function testBatchMintToERC1155Recipient() public {
        ERC1155Recipient to = new ERC1155Recipient();

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

        token.batchMint(address(to), ids, amounts, "testing 123");

        assertEq(to.batchOperator(), address(this));
        assertEq(to.batchFrom(), address(0));
        assertUintArrayEq(to.batchIds(), ids);
        assertUintArrayEq(to.batchAmounts(), amounts);
        assertBytesEq(to.batchData(), "testing 123");

        assertEq(token.balanceOf(address(to), 1337), 1);
        assertEq(token.balanceOf(address(to), 1338), 1);
        assertEq(token.balanceOf(address(to), 1339), 1);
        assertEq(token.balanceOf(address(to), 1340), 1);
        assertEq(token.balanceOf(address(to), 1341), 1);
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
        mintAmounts[0] = 1;
        mintAmounts[1] = 1;
        mintAmounts[2] = 1;
        mintAmounts[3] = 1;
        mintAmounts[4] = 1;

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

    function testSafeTransferFromToERC1155Recipient() public {
        ERC1155Recipient to = new ERC1155Recipient();

        address from = address(0xABCD);

        token.mint(from, 1337, 1, "");

        hevm.prank(from);
        token.setApprovalForAll(address(this), true);

        token.safeTransferFrom(from, address(to), 1337, 1, "testing 123");

        assertEq(to.operator(), address(this));
        assertEq(to.from(), from);
        assertEq(to.id(), 1337);
        assertBytesEq(to.mintData(), "testing 123");

        assertEq(token.balanceOf(address(to), 1337), 1);
        assertEq(token.balanceOf(from, 1337), 0);
    }

    function testSafeTransferFromSelf() public {
        token.mint(address(this), 1337, 1, "");

        token.safeTransferFrom(address(this), address(0xBEEF), 1337, 1, "");

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

    function testFailMintToZero() public {
        token.mint(address(0), 1337, 1, "");
    }

    function testFailMintToNonERC155Recipient() public {
        token.mint(address(new NonERC1155Recipient()), 1337, 1, "");
    }

    function testFailMintToRevertingERC155Recipient() public {
        token.mint(address(new RevertingERC1155Recipient()), 1337, 1, "");
    }

    function testFailMintToWrongReturnDataERC155Recipient() public {
        token.mint(address(new RevertingERC1155Recipient()), 1337, 1, "");
    }

    function testFailSafeTransferFromToZero() public {
        token.mint(address(this), 1337, 1, "");
        token.safeTransferFrom(address(this), address(0), 1337, 1, "");
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

    function testFailSafeBatchTransferFromWithArrayLengthMismatch() public {
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

        uint256[] memory transferAmounts = new uint256[](4);
        transferAmounts[0] = 1;
        transferAmounts[1] = 1;
        transferAmounts[2] = 1;
        transferAmounts[3] = 1;

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
    }

    function testFailBatchMintToZero() public {
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

        token.batchMint(address(0), ids, mintAmounts, "");
    }

    function testFailBatchMintToNonERC1155Recipient() public {
        NonERC1155Recipient to = new NonERC1155Recipient();

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

        token.batchMint(address(to), ids, mintAmounts, "");
    }

    function testFailBatchMintToRevertingERC1155Recipient() public {
        RevertingERC1155Recipient to = new RevertingERC1155Recipient();

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

        token.batchMint(address(to), ids, mintAmounts, "");
    }

    function testFailBatchMintToWrongReturnDataERC1155Recipient() public {
        WrongReturnDataERC1155Recipient to = new WrongReturnDataERC1155Recipient();

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

        token.batchMint(address(to), ids, mintAmounts, "");
    }

    function testFailBatchMintWithArrayMismatch() public {
        uint256[] memory ids = new uint256[](5);
        ids[0] = 1337;
        ids[1] = 1338;
        ids[2] = 1339;
        ids[3] = 1340;
        ids[4] = 1341;

        uint256[] memory amounts = new uint256[](4);
        amounts[0] = 1;
        amounts[1] = 1;
        amounts[2] = 1;
        amounts[3] = 1;

        token.batchMint(address(0xBEEF), ids, amounts, "");
    }

    // function testFailBatchBurnInsufficientBalance() public {
    //     uint256[] memory ids = new uint256[](5);
    //     ids[0] = 1337;
    //     ids[1] = 1338;
    //     ids[2] = 1339;
    //     ids[3] = 1340;
    //     ids[4] = 1341;

    //     uint256[] memory mintAmounts = new uint256[](5);
    //     mintAmounts[0] = 1;
    //     mintAmounts[1] = 1;
    //     mintAmounts[2] = 1;
    //     mintAmounts[3] = 1;
    //     mintAmounts[4] = 1;

    //     uint256[] memory burnAmounts = new uint256[](5);
    //     burnAmounts[0] = 1;
    //     burnAmounts[1] = 1;
    //     burnAmounts[2] = 1;
    //     burnAmounts[3] = 1;
    //     burnAmounts[4] = 1;

    //     token.batchMint(address(0xBEEF), ids, mintAmounts, "");

    //     token.batchBurn(address(0xBEEF), ids, burnAmounts);
    // }

    function testFailBatchBurnWithArrayLengthMismatch() public {
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

        uint256[] memory burnAmounts = new uint256[](4);
        burnAmounts[0] = 1;
        burnAmounts[1] = 1;
        burnAmounts[2] = 1;
        burnAmounts[3] = 1;

        token.batchMint(address(0xBEEF), ids, mintAmounts, "");

        token.batchBurn(address(0xBEEF), ids, burnAmounts);
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

    function testMintToEOA(
        address to,
        uint256 id,
        bytes memory mintData
    ) public {
        if (to == address(0)) to = address(0xBEEF);

        if (uint256(uint160(to)) <= 18 || to.code.length > 0) return;

        token.mint(to, id, 1, mintData);

        assertEq(token.balanceOf(to, id), 1);
    }

    function testMintToERC1155Recipient(
        uint256 id,
        bytes memory mintData
    ) public {
        ERC1155Recipient to = new ERC1155Recipient();

        token.mint(address(to), id, 1, mintData);

        assertEq(token.balanceOf(address(to), id), 1);

        assertEq(to.operator(), address(this));
        assertEq(to.from(), address(0));
        assertEq(to.id(), id);
        assertBytesEq(to.mintData(), mintData);
    }
}
