// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import '@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol';
import './interface/IReverseRegistrar.sol';
import './interface/IFNSRegistry.sol';
import './interface/INameResolver.sol';

contract ReverseRegistrar is IReverseRegistrar, ContextUpgradeable {
    // namehash('addr.reverse')
    bytes32 public constant ADDR_REVERSE_NODE = 0x91d1777781884d03a6757a803996e38de2a42967fb37eeaca72729271025a9e2;

    IFNSRegistry public fnsRegistry;
    INameResolver public defaultResolver;

    /**
     * @dev Constructor
     * @param fnsRegistryAddr The address of the FNS registry.
     * @param resolverAddr The address of the default reverse resolver.
     */
    function initialize(IFNSRegistry fnsRegistryAddr, INameResolver resolverAddr) public initializer {
        __Context_init();
        fnsRegistry = fnsRegistryAddr;
        defaultResolver = resolverAddr;
    }

    /**
     * @dev Returns the node hash for a given account's reverse records.
     * @param addr The address to hash
     * @return The FNS node hash.
     */
    function getNode(address addr) external pure returns (bytes32) {
        return keccak256(abi.encodePacked(ADDR_REVERSE_NODE, sha3HexAddress(addr)));
    }

    /**
     * @dev Sets the `name()` record for the reverse FNS record associated with
     * the calling account. First updates the resolver to the default reverse
     * resolver if necessary.
     * @param name The name to set for this address.
     * @return The FNS node hash of the reverse record.
     */
    function setName(string memory name) public returns (bytes32) {
        bytes32 node = claimWithResolver(address(defaultResolver));
        defaultResolver.setName(node, name);
        return node;
    }

    /**
     * @dev Transfers ownership of the reverse FNS record associated with the
     *      calling account.
     * @param resolver The address of the resolver to set; 0 to leave unchanged.
     * @return The FNS node hash of the reverse record.
     */
    function claimWithResolver(address resolver) internal returns (bytes32) {
        bytes32 label = sha3HexAddress(msg.sender);
        string memory labelStr = StringsUpgradeable.toHexString(uint256(uint160(msg.sender)));
        bytes32 node = keccak256(abi.encodePacked(ADDR_REVERSE_NODE, label));
        address currentOwner = fnsRegistry.currentOwner(node);

        // Update the owner if required
        if (currentOwner == address(0x0)) {
            fnsRegistry.setSubnodeOwner(ADDR_REVERSE_NODE, labelStr, label, address(this));
            fnsRegistry.setResolver(node, resolver);
        }

        return node;
    }

    /**
     * @dev An optimised function to compute the sha3 of the lower-case
     *      hexadecimal representation of an Ethereum address.
     * @param addr The address to hash
     * @return ret The SHA3 hash of the lower-case hexadecimal encoding of the
     *         input address.
     */
    function sha3HexAddress(address addr) internal pure returns (bytes32 ret) {
        addr;
        ret; // Stop warning us about unused variables
        assembly {
            let lookup := 0x3031323334353637383961626364656600000000000000000000000000000000

            for { let i := 40 } gt(i, 0) { } {
                i := sub(i, 1)
                mstore8(i, byte(and(addr, 0xf), lookup))
                addr := div(addr, 0x10)
                i := sub(i, 1)
                mstore8(i, byte(and(addr, 0xf), lookup))
                addr := div(addr, 0x10)
            }

            ret := keccak256(0, 40)
        }
    }
}