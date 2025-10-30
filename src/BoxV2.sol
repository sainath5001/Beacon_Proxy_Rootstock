// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Initializable} from "openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";

/**
 * @title BoxV2
 * @dev Upgraded version of BoxV1 with additional functionality
 * This contract demonstrates how to extend functionality while maintaining storage compatibility
 */
contract BoxV2 is Initializable {
    /// @dev Storage variable - maintained across upgrades (same layout as V1)
    uint256 private _value;

    /// @dev Owner address (same as V1)
    address private _owner;

    /// @dev NEW: Additional storage variable added in V2
    uint256 private _version;

    /// @dev NEW: History of all value changes
    mapping(uint256 => uint256) private _valueHistory;
    uint256 private _historyCount;

    /// @dev Emitted when value is changed
    event ValueChanged(uint256 newValue);

    /// @dev Emitted when ownership is transferred
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /// @dev NEW: Emitted when value history is queried
    event HistoryQueried(uint256 index, uint256 value);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Initialize the contract (for fresh deployments)
     * @param initialValue The initial value to set
     * @param initialOwner The initial owner address
     */
    function initialize(uint256 initialValue, address initialOwner) public initializer {
        _value = initialValue;
        _owner = initialOwner;
        _version = 2;
        _valueHistory[0] = initialValue;
        _historyCount = 1;
        emit ValueChanged(initialValue);
        emit OwnershipTransferred(address(0), initialOwner);
    }

    /**
     * @dev Migrate from V1 to V2 (called after upgrade)
     * This function can be called to initialize V2-specific features
     */
    function migrateToV2() public reinitializer(2) {
        _version = 2;
        _valueHistory[0] = _value;
        _historyCount = 1;
    }

    /**
     * @dev Get the current value
     * @return The current stored value
     */
    function getValue() public view returns (uint256) {
        return _value;
    }

    /**
     * @dev Set a new value (enhanced in V2 to track history)
     * @param newValue The new value to set
     */
    function setValue(uint256 newValue) public {
        require(msg.sender == _owner, "BoxV2: caller is not the owner");
        _value = newValue;
        _valueHistory[_historyCount] = newValue;
        _historyCount++;
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
        require(msg.sender == _owner, "BoxV2: caller is not the owner");
        require(newOwner != address(0), "BoxV2: new owner is the zero address");

        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }

    /**
     * @dev NEW: Get the contract version
     * @return The version number
     */
    function getVersion() public view returns (uint256) {
        return _version;
    }

    /**
     * @dev NEW: Get value from history
     * @param index The index in the history
     * @return The value at that index
     */
    function getValueFromHistory(uint256 index) public view returns (uint256) {
        require(index < _historyCount, "BoxV2: index out of bounds");
        return _valueHistory[index];
    }

    /**
     * @dev NEW: Get the total number of value changes
     * @return The count of value changes
     */
    function getHistoryCount() public view returns (uint256) {
        return _historyCount;
    }

    /**
     * @dev NEW: Increment value (new convenience function in V2)
     */
    function increment() public {
        require(msg.sender == _owner, "BoxV2: caller is not the owner");
        setValue(_value + 1);
    }

    /**
     * @dev NEW: Decrement value (new convenience function in V2)
     */
    function decrement() public {
        require(msg.sender == _owner, "BoxV2: caller is not the owner");
        require(_value > 0, "BoxV2: value cannot be negative");
        setValue(_value - 1);
    }
}
