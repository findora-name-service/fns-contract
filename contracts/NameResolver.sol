// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import './interface/INameResolver.sol';

contract NameResolver is INameResolver, Initializable {

    mapping (bytes32 => string) public name;

    function initialize() public initializer {}

    function setName(bytes32 node, string memory _name) external {
        name[node] = _name;
    }
}