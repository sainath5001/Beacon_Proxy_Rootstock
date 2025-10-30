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

        vm.startBroadcast(deployerPrivateKey);

        // Get the existing beacon
        UpgradeableBeacon beacon = UpgradeableBeacon(beaconAddress);
        address oldImplementation = beacon.implementation();
        console.log("\nCurrent implementation (V1):", oldImplementation);

        // Step 1: Deploy the new implementation contract (BoxV2)
        console.log("\n=== Step 1: Deploying New Implementation Contract (BoxV2) ===");
        BoxV2 newImplementation = new BoxV2();
        console.log("BoxV2 implementation deployed at:", address(newImplementation));

        // Step 2: Upgrade the beacon to point to the new implementation
        console.log("\n=== Step 2: Upgrading Beacon ===");
        beacon.upgradeTo(address(newImplementation));
        console.log("Beacon upgraded!");
        console.log("New implementation (V2):", beacon.implementation());

        // Step 3: Get proxy addresses (you can get these from deployment or env vars)
        // For demonstration, we'll assume you have proxy addresses
        address proxy1Address = vm.envOr("PROXY_1_ADDRESS", address(0));
        address proxy2Address = vm.envOr("PROXY_2_ADDRESS", address(0));
        address proxy3Address = vm.envOr("PROXY_3_ADDRESS", address(0));

        if (proxy1Address != address(0)) {
            console.log("\n=== Step 3: Migrating Proxies to V2 ===");

            BoxV2 proxy1 = BoxV2(proxy1Address);
            BoxV2 proxy2 = BoxV2(proxy2Address);
            BoxV2 proxy3 = BoxV2(proxy3Address);

            // Migrate each proxy to V2 features
            console.log("Migrating Proxy 1...");
            proxy1.migrateToV2();
            console.log("Proxy 1 version:", proxy1.getVersion());
            console.log("Proxy 1 value (preserved):", proxy1.getValue());

            if (proxy2Address != address(0)) {
                console.log("Migrating Proxy 2...");
                proxy2.migrateToV2();
                console.log("Proxy 2 version:", proxy2.getVersion());
                console.log("Proxy 2 value (preserved):", proxy2.getValue());
            }

            if (proxy3Address != address(0)) {
                console.log("Migrating Proxy 3...");
                proxy3.migrateToV2();
                console.log("Proxy 3 version:", proxy3.getVersion());
                console.log("Proxy 3 value (preserved):", proxy3.getValue());
            }
        }

        vm.stopBroadcast();

        console.log("\n=== Upgrade Summary ===");
        console.log("Beacon upgraded to BoxV2");
        console.log("All proxies now use the new implementation!");
        console.log("New features available: getVersion(), increment(), decrement(), getValueFromHistory()");
    }
}
