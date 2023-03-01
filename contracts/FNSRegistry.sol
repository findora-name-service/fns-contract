// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;
pragma experimental ABIEncoderV2;

import '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol';
import "./interface/IFNSRegistry.sol";

contract FNSRegistry is IFNSRegistry, OwnableUpgradeable {

    struct Record {
        address owner;
        address resolver;
        string text;
        uint256 expirie;
        uint8 level;
    }

    struct RegistDetail {
        uint256 index;
        string labelStr;
    }

    uint8 public constant MAX_LEVEL = 3;

    uint8 public constant MAX_SUB_COUNT = 10;

    mapping (bytes32 => Record) public records;

    mapping (bytes32 => bytes32) public parentRelations;
    mapping (bytes32 => bytes32[]) public subRelations;
    mapping (bytes32 => RegistDetail) public subDetails;

    mapping (bytes32 => address) public operators;

    EnumerableSetUpgradeable.AddressSet private managers;

    // namehash('addr.reverse')
    bytes32 public constant ADDR_REVERSE_NODE = 0x91d1777781884d03a6757a803996e38de2a42967fb37eeaca72729271025a9e2;

    modifier authorised(bytes32 node) {
        address owner = records[node].owner;
        require(owner == msg.sender || operators[node] == msg.sender, 'not owner or operators');
        _;
    }

    modifier checkExpirie(bytes32 node) {
        uint256 expirie = records[node].expirie;
        require(expirie == 0 || expirie >= block.timestamp, 'expired');
        _;
    }

    modifier checkRule(bytes32 node) {
        require(records[node].level < MAX_LEVEL, 'exceeds max level');
        if(node != ADDR_REVERSE_NODE){
            require(subRelations[node].length < MAX_SUB_COUNT, 'exceeds max sub count');
        }
        _;
    }

    modifier onlyManager() {
        require(isManager(msg.sender), "FNSRegistry: Caller is not the manager");
        _;
    }

    event AddOwner(bytes32 indexed parentNode, bytes32 indexed subNode, address owner);
    event AddSubOwner(bytes32 indexed parentNode, bytes32 indexed subNode, address owner);
    event DelSubOwner(bytes32 indexed parentNode, bytes32 indexed subNode, address owner);
    event Transfer(bytes32 indexed node, address owner);
    event NewExpirie(bytes32 indexed node, uint256 expirie);
    event NewResolver(bytes32 indexed node, address resolver);
    event NewText(bytes32 indexed node, string text);
    event ApprovalForAll(address indexed owner, bytes32 indexed node, address indexed operator);
    event NewManager(address indexed owner, address indexed newOperator);
    event DelManager(address indexed owner, address indexed delOperator);

    function initialize() public initializer {
        __Context_init_unchained();
        __Ownable_init_unchained();
        records[0x0].owner = msg.sender;
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

    function setSubnodeOwner(
        bytes32 parentNode,
        string memory labelStr,
        bytes32 label,
        address owner
    ) external
        authorised(parentNode)
        checkExpirie(parentNode)
        checkRule(parentNode)
        returns(bytes32)
    {
        bytes32 subNode = keccak256(abi.encodePacked(parentNode, label));
        _setOwner(subNode, owner);
        _setLevel(parentNode, subNode);
        _setExpirie(subNode, records[parentNode].expirie);
        if(records[subNode].level > 2){
            _setSubRelations(parentNode, subNode, labelStr);
        }
        emit AddSubOwner(subNode, label, owner);
        return subNode;
    }

    function delSubnodeOwner(
        bytes32 node
    ) external
        authorised(node)
    {
        require(records[node].level > 2, 'cannot');
        _delOwner(node);
    }

    function delAllSubnodeOwner(
        bytes32 node
    ) external
        onlyManager
    {
        require(records[node].level == 2, 'cannot');
        _delOwner(node);
    }

    function setOwner(
        bytes32 node, 
        address owner
    ) external 
        onlyManager
    {
        require(records[node].level == 2, 'cannot');
        _setOwner(node, owner);
        emit Transfer(node, owner);
    }

    function setExpirie(
        bytes32 node, 
        uint256 expirie
    ) external 
        onlyManager 
    {
        _setExpirie(node, expirie);
        emit NewExpirie(node, expirie);
    }

    function setResolver(
        bytes32 node, 
        address resolver
    ) external 
        authorised(node)
        checkExpirie(node)
    {
        records[node].resolver = resolver;
        emit NewResolver(node, resolver);
    }

    function setDefaultText(
        bytes32 node, 
        string memory text
    ) external 
        onlyManager
    {
        records[node].text = text;
        emit NewText(node, text);
    }

    function setText(
        bytes32 node, 
        string memory text
    ) external 
        authorised(node)
        checkExpirie(node)
    {
        records[node].text = text;
        emit NewText(node, text);
    }

    function setApprovalForAll(
        bytes32 node, 
        address operator
    ) external
        authorised(node)
        checkExpirie(node)
    {
        operators[node] = operator;
        emit ApprovalForAll(msg.sender, node, operator);
    }

    function recordExists(
        bytes32 node
    ) external view 
        returns (bool)
    {
        return records[node].owner != address(0x0) && records[node].expirie > block.timestamp;
    }

    function currentOwner(
        bytes32 node
    ) external view 
        checkExpirie(node)
        returns (address)
    {
        address addr = records[node].owner;
        if (addr == address(this)) {
            return address(0x0);
        }
        return addr;
    }

    function currentResolver(
        bytes32 node
    ) external view 
        checkExpirie(node) 
        returns (address)
    {
        return records[node].resolver;
    }

    function currentText(
        bytes32 node
    ) external view 
        checkExpirie(node)
        returns (string memory)
    {
        return records[node].text;
    }

    function isApprovedForAll(
        bytes32 node, 
        address operator
    ) external view 
        returns (bool)
    {
        return operators[node] == operator;
    }

    function _setOwner(
        bytes32 node, 
        address owner
    ) internal {
        records[node].owner = owner;
    }

    function _setLevel(
        bytes32 parentNode, 
        bytes32 subNode
    ) internal {
        uint8 parentLevel = records[parentNode].level;
        records[subNode].level = parentLevel + 1;
    }

    function _setExpirie(
        bytes32 node,
        uint256 expirie
    ) internal {
        records[node].expirie = expirie;
        bytes32[] storage subArray = subRelations[node];
        for(uint256 i = 0; i < subArray.length; i++){
            records[subArray[i]].expirie = expirie;
        }
    }

    function _setSubRelations(bytes32 parentNode, bytes32 subNode, string memory labelStr) internal {
        parentRelations[subNode] = parentNode;
        subRelations[parentNode].push(subNode);
        subDetails[subNode] = RegistDetail({
            index: subRelations[parentNode].length - 1,
            labelStr: labelStr
        });
    }

    function _delOwner(bytes32 node) internal {
        uint8 level = records[node].level;
        if(level == 2){
            bytes32[] storage subArray = subRelations[node];
            for(uint256 i = 0; i < subArray.length; i++){
                delete subDetails[subArray[i]];
                delete records[subArray[i]];
                delete parentRelations[subArray[i]];
            }
            delete subRelations[node];
        }else{
            uint256 index = subDetails[node].index;
            bytes32 parentNode = parentRelations[node];
            require(node == subRelations[parentNode][index], 'error');
            bytes32[] storage subArray = subRelations[parentNode];
            subDetails[subArray[subArray.length - 1]].index = index;
            subRelations[parentNode][index] = subRelations[parentNode][subArray.length - 1];
            subRelations[parentNode].pop();
            delete subDetails[node];
            delete parentRelations[node];
            delete records[node];
        }
    }

    function getSubRelations(bytes32 parentNode) external view returns (bytes32[] memory) {
        return subRelations[parentNode];
    }
}