// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface IReverseRegistrar {
    function getNode(address addr) external pure returns (bytes32);
    function setName(string memory name) external returns (bytes32);
}