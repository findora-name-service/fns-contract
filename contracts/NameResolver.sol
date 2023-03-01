// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol';
import './interface/INameResolver.sol';

contract NameResolver is INameResolver, OwnableUpgradeable {

    EnumerableSetUpgradeable.AddressSet private managers;

    mapping (bytes32 => string) public name;

    bytes32 constant HASH_EMPTY_STRING = keccak256(abi.encode(''));

    modifier onlyManager() {
        require(isManager(msg.sender), "NameResolver: Caller is not the manager");
        _;
    }

    event NewManager(address indexed owner, address indexed newOperator);
    event DelManager(address indexed owner, address indexed delOperator);

    function initialize() public initializer {
        __Context_init();
        __Ownable_init();
    }

    function addManager(address manager) external onlyOwner {
        EnumerableSetUpgradeable.add(managers, manager);
        emit NewManager(msg.sender, manager);
    }

    function delManager(address manager) external onlyOwner {
        EnumerableSetUpgradeable.remove(managers, manager);
        emit DelManager(msg.sender, manager);
    }

    function isManager(address manager) public view returns (bool) {
        return EnumerableSetUpgradeable.contains(managers, manager);
    }

    function setName(bytes32 node, string memory _name) external {
        name[node] = _name;
    }

    function delName(bytes32 node) external onlyManager returns (bool){
        if(keccak256(abi.encode(name[node])) != HASH_EMPTY_STRING){
            delete name[node];
        }
        return true;
    }
}