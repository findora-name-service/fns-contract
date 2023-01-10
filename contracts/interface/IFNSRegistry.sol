// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface IFNSRegistry {
    function setSubnodeOwner(bytes32 parentNode, string memory labelStr, bytes32 label, address owner) external returns(bytes32);
    function delSubnodeOwner(bytes32 node) external;
    function delAllSubnodeOwner(bytes32 node) external;
    function setOwner(bytes32 node, address owner) external;
    function setExpirie(bytes32 node, uint256 expirie) external;
    function setResolver(bytes32 node, address resolver) external;
    function setText(bytes32 node, string memory text) external;
    function setDefaultText(bytes32 node, string memory text) external;
    function setApprovalForAll(bytes32 node, address operator) external;
    function recordExists(bytes32 node) external view returns (bool);
    function currentOwner(bytes32 node) external view returns (address);
    function currentResolver(bytes32 node) external view returns (address);
    function currentText(bytes32 node) external view returns (string memory);
    function isApprovedForAll(bytes32 node, address operator) external view returns (bool);
    function getSubRelations(bytes32 parentNode) external view returns (bytes32[] memory);
}