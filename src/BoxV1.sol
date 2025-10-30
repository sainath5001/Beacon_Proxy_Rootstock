// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Initializable} from "openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";

/**
 * @title BoxV1
 * @dev Example implementation contract for Beacon Proxy Pattern
 * This contract demonstrates a simple storage contract that can be upgraded
 */
contract BoxV1 is Initializable {
    /// @dev Storage variable - maintained across upgrades
    uint256 private _value;

    /// @dev Owner address
    address private _owner;

    /// @dev Emitted when value is changed
    event ValueChanged(uint256 newValue);

    /// @dev Emitted when ownership is transferred
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Initialize the contract (replaces constructor for upgradeable contracts)
     * @param initialValue The initial value to set
     * @param initialOwner The initial owner address
     */
    function initialize(uint256 initialValue, address initialOwner) public initializer {
        _value = initialValue;
        _owner = initialOwner;
        emit ValueChanged(initialValue);
        emit OwnershipTransferred(address(0), initialOwner);
    }

    /**
     * @dev Get the current value
     * @return The current stored value
     */
    function getValue() public view returns (uint256) {
        return _value;
    }

    /**
     * @dev Set a new value
     * @param newValue The new value to set
     */
    function setValue(uint256 newValue) public {
        require(msg.sender == _owner, "BoxV1: caller is not the owner");
        _value = newValue;
        emit ValueChanged(newValue);
    }

    /**
     * @dev Get the owner address
     * @return The owner address
     */
    function getOwner() public view returns (address) {
        return _owner;
    }

    /**
     * @dev Transfer ownership to a new address
     * @param newOwner The address to transfer ownership to
     */
    function transferOwnership(address newOwner) public {
        require(msg.sender == _owner, "BoxV1: caller is not the owner");
        require(newOwner != address(0), "BoxV1: new owner is the zero address");

        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}
