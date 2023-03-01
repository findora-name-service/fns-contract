// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface INameResolver {
    function setName(bytes32 node, string memory name) external;
    function delName(bytes32 node) external returns (bool);
}