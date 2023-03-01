// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

// helper methods for interacting with ERC20 tokens and sending FRA that do not consistently return true/false
library TransferHelper {

    function safeBalanceOf(
        address token,
        address target
    ) internal returns (uint256){
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x70a08231, target));
        require(success, 'TransferHelper: BALANCE_OF_FAILED');
        return abi.decode(data, (uint256));
    }

    function safeTransfer(
        address token,
        address to,
        uint256 value
    ) internal {
        // bytes4(keccak256(bytes('transfer(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0xa9059cbb, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: TRANSFER_FAILED');
    }

    function safeTransferFrom(
        address token,
        address from,
        address to,
        uint256 value
    ) internal {
        // bytes4(keccak256(bytes('transferFrom(address,address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x23b872dd, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: TRANSFER_FROM_FAILED');
    }

    function safeTransferFRA(address to, uint256 value) internal {
        (bool success, ) = to.call{value: value}(new bytes(0));
        require(success, 'TransferHelper: FRA_TRANSFER_FAILED');
    }
}
