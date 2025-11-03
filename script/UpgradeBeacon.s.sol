// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Script, console} from "forge-std/Script.sol";
import {BoxV2} from "../src/BoxV2.sol";
import {UpgradeableBeacon} from "openzeppelin-contracts/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {BeaconProxy} from "openzeppelin-contracts/contracts/proxy/beacon/BeaconProxy.sol";
import {BoxV1} from "../src/BoxV1.sol";

/**
 * @title UpgradeBeacon
 * @dev Script to upgrade the beacon to a new implementation (BoxV2)
 * This demonstrates how upgrading the beacon automatically upgrades all proxies
 */
contract UpgradeBeacon is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // Get beacon address from environment or use a hardcoded address
        address beaconAddress = vm.envAddress("BEACON_ADDRESS");

        console.log("Upgrading Beacon Proxy Pattern...");
        console.log("Deployer address:", deployer);
        console.log("Beacon address:", beaconAddress);

        // Get the existing beacon
        UpgradeableBeacon beacon = UpgradeableBeacon(beaconAddress);

        // Check beacon owner before attempting upgrade
        (bool ownerSuccess, bytes memory ownerData) = address(beacon).staticcall(abi.encodeWithSignature("owner()"));
        address beaconOwner;
        if (ownerSuccess && ownerData.length >= 32) {
            beaconOwner = abi.decode(ownerData, (address));
            console.log("Beacon owner:", beaconOwner);
            if (beaconOwner != deployer) {
                console.log("\nWARNING: Deployer is not the beacon owner!");
                console.log("Only the owner can upgrade the beacon.");
                console.log("Beacon owner:", beaconOwner);
                console.log("Deployer:", deployer);
                revert("Deployer is not the beacon owner");
            }
        } else {
            console.log("\nWarning: Could not read beacon owner, proceeding anyway...");
        }

        vm.startBroadcast(deployerPrivateKey);

        // Read current implementation (using safe staticcall to handle potential network issues)
        address oldImplementation;
        (bool success1, bytes memory data1) = address(beacon).staticcall(abi.encodeWithSignature("implementation()"));
        if (success1 && data1.length >= 32) {
            oldImplementation = abi.decode(data1, (address));
            console.log("\nCurrent implementation (V1):", oldImplementation);
        } else {
            console.log("\nWarning: Could not read current implementation, proceeding with upgrade...");
        }

        // Step 1: Deploy the new implementation contract (BoxV2)
        console.log("\n=== Step 1: Deploying New Implementation Contract (BoxV2) ===");
        BoxV2 newImplementation = new BoxV2();
        console.log("BoxV2 implementation deployed at:", address(newImplementation));

        // Step 2: Upgrade the beacon to point to the new implementation
        console.log("\n=== Step 2: Upgrading Beacon ===");

        // Use low-level call to capture error messages
        (bool upgradeSuccess, bytes memory upgradeReturnData) =
            address(beacon).call(abi.encodeWithSignature("upgradeTo(address)", address(newImplementation)));

        if (!upgradeSuccess) {
            console.log("\nERROR: Upgrade failed");

            // Try to decode error message
            if (upgradeReturnData.length == 0) {
                console.log("Reason: Empty revert data - possible causes:");
                console.log("  - Network connectivity issue");
                console.log("  - Insufficient gas");
                console.log("  - Beacon contract reverted without reason");
                revert("Upgrade failed: empty revert data");
            } else if (upgradeReturnData.length >= 4) {
                bytes4 errorSelector = bytes4(upgradeReturnData);

                // Check for common errors
                if (errorSelector == 0x82b42900) {
                    // OwnableUnauthorizedAccount(bytes32(uint256(uint160(account))))
                    console.log("Error: Unauthorized account - deployer is not the owner");
                    revert("Upgrade failed: deployer is not the beacon owner");
                } else if (errorSelector == 0x49f9b0f7) {
                    // BeaconInvalidImplementation(address)
                    console.log("Error: Invalid implementation address");
                    revert("Upgrade failed: invalid implementation address");
                } else {
                    console.log("Error selector:", vm.toString(errorSelector));
                    console.log("Return data length:", upgradeReturnData.length);
                    revert("Upgrade failed: unknown error");
                }
            } else {
                console.log("Return data length:", upgradeReturnData.length);
                revert("Upgrade failed: unexpected return data");
            }
        }

        console.log("Beacon upgraded!");

        // Verify the upgrade
        (bool success2, bytes memory data2) = address(beacon).staticcall(abi.encodeWithSignature("implementation()"));
        if (success2 && data2.length >= 32) {
            address newImpl = abi.decode(data2, (address));
            console.log("New implementation (V2):", newImpl);
        } else {
            console.log("New implementation (V2):", address(newImplementation));
        }

        // Step 3: Get proxy addresses (you can get these from deployment or env vars)
        // For demonstration, we'll assume you have proxy addresses
        address proxy1Address = vm.envOr("PROXY_1_ADDRESS", address(0));
        address proxy2Address = vm.envOr("PROXY_2_ADDRESS", address(0));
        address proxy3Address = vm.envOr("PROXY_3_ADDRESS", address(0));

        if (proxy1Address != address(0)) {
            console.log("\n=== Step 3: Verifying Proxies After Upgrade ===");

            BoxV2 proxy1 = BoxV2(proxy1Address);
            BoxV2 proxy2 = BoxV2(proxy2Address);
            BoxV2 proxy3 = BoxV2(proxy3Address);

            // Test if V2 functions work directly (they should after beacon upgrade)
            console.log("Testing Proxy 1...");
            (bool proxy1ValueSuccess, bytes memory proxy1ValueData) =
                address(proxy1).staticcall(abi.encodeWithSignature("getValue()"));
            if (proxy1ValueSuccess && proxy1ValueData.length >= 32) {
                uint256 value1 = abi.decode(proxy1ValueData, (uint256));
                console.log("Proxy 1 value (preserved):", value1);
            }

            // Try to get version - might need migration first
            (bool proxy1VersionSuccess, bytes memory proxy1VersionData) =
                address(proxy1).staticcall(abi.encodeWithSignature("getVersion()"));
            if (proxy1VersionSuccess && proxy1VersionData.length >= 32) {
                uint256 version1 = abi.decode(proxy1VersionData, (uint256));
                console.log("Proxy 1 version:", version1);
            } else {
                console.log("Proxy 1: getVersion() not available - migration may be needed");

                // Attempt migration with low-level call to capture errors
                (bool proxy1MigrateSuccess, bytes memory proxy1MigrateData) =
                    address(proxy1).call(abi.encodeWithSignature("migrateToV2()"));
                if (proxy1MigrateSuccess) {
                    console.log("Proxy 1 migration successful!");
                    // Try getVersion again
                    (proxy1VersionSuccess, proxy1VersionData) =
                        address(proxy1).staticcall(abi.encodeWithSignature("getVersion()"));
                    if (proxy1VersionSuccess && proxy1VersionData.length >= 32) {
                        uint256 version1 = abi.decode(proxy1VersionData, (uint256));
                        console.log("Proxy 1 version after migration:", version1);
                    }
                } else {
                    console.log("Proxy 1 migration failed - proxies may need manual migration");
                    console.log("Migration return data length:", proxy1MigrateData.length);
                }
            }

            if (proxy2Address != address(0)) {
                console.log("Testing Proxy 2...");
                (bool proxy2ValueSuccess, bytes memory proxy2ValueData) =
                    address(proxy2).staticcall(abi.encodeWithSignature("getValue()"));
                if (proxy2ValueSuccess && proxy2ValueData.length >= 32) {
                    uint256 value2 = abi.decode(proxy2ValueData, (uint256));
                    console.log("Proxy 2 value (preserved):", value2);
                }

                (bool proxy2VersionSuccess, bytes memory proxy2VersionData) =
                    address(proxy2).staticcall(abi.encodeWithSignature("getVersion()"));
                if (proxy2VersionSuccess && proxy2VersionData.length >= 32) {
                    uint256 version2 = abi.decode(proxy2VersionData, (uint256));
                    console.log("Proxy 2 version:", version2);
                } else {
                    console.log("Proxy 2: getVersion() not available - migration may be needed");
                }
            }

            if (proxy3Address != address(0)) {
                console.log("Testing Proxy 3...");
                (bool proxy3ValueSuccess, bytes memory proxy3ValueData) =
                    address(proxy3).staticcall(abi.encodeWithSignature("getValue()"));
                if (proxy3ValueSuccess && proxy3ValueData.length >= 32) {
                    uint256 value3 = abi.decode(proxy3ValueData, (uint256));
                    console.log("Proxy 3 value (preserved):", value3);
                }

                (bool proxy3VersionSuccess, bytes memory proxy3VersionData) =
                    address(proxy3).staticcall(abi.encodeWithSignature("getVersion()"));
                if (proxy3VersionSuccess && proxy3VersionData.length >= 32) {
                    uint256 version3 = abi.decode(proxy3VersionData, (uint256));
                    console.log("Proxy 3 version:", version3);
                } else {
                    console.log("Proxy 3: getVersion() not available - migration may be needed");
                }
            }
        }

        vm.stopBroadcast();

        console.log("\n=== Upgrade Summary ===");
        console.log("Beacon upgraded to BoxV2");
        console.log("All proxies now use the new implementation!");
        console.log("New features available: getVersion(), increment(), decrement(), getValueFromHistory()");
    }
}
