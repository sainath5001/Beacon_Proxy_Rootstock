// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Script, console} from "forge-std/Script.sol";
import {BoxV1} from "../src/BoxV1.sol";
import {UpgradeableBeacon} from "openzeppelin-contracts/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {BeaconProxy} from "openzeppelin-contracts/contracts/proxy/beacon/BeaconProxy.sol";

/**
 * @title DeployBeaconProxy
 * @dev Deployment script for Beacon Proxy Pattern on Rootstock
 * This script deploys:
 * 1. Implementation contract (BoxV1)
 * 2. UpgradeableBeacon contract
 * 3. Multiple BeaconProxy instances that reference the beacon
 */
contract DeployBeaconProxy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deploying Beacon Proxy Pattern...");
        console.log("Deployer address:", deployer);
        console.log("Deployer balance:", deployer.balance);

        vm.startBroadcast(deployerPrivateKey);

        // Step 1: Deploy the implementation contract (BoxV1)
        console.log("\n=== Step 1: Deploying Implementation Contract (BoxV1) ===");
        BoxV1 implementation = new BoxV1();
        console.log("BoxV1 implementation deployed at:", address(implementation));

        // Step 2: Deploy the UpgradeableBeacon
        console.log("\n=== Step 2: Deploying UpgradeableBeacon ===");
        UpgradeableBeacon beacon = new UpgradeableBeacon(
            address(implementation),
            deployer // initial owner
        );
        console.log("UpgradeableBeacon deployed at:", address(beacon));
        console.log("Beacon implementation:", beacon.implementation());

        // Step 3: Deploy multiple BeaconProxy instances
        console.log("\n=== Step 3: Deploying BeaconProxy Instances ===");

        // Prepare initialization data
        bytes memory initData = abi.encodeWithSelector(
            BoxV1.initialize.selector,
            100, // initial value
            deployer // initial owner
        );

        // Deploy Proxy 1
        BeaconProxy proxy1 = new BeaconProxy(address(beacon), initData);
        console.log("BeaconProxy 1 deployed at:", address(proxy1));

        // Deploy Proxy 2 with different initial value
        bytes memory initData2 = abi.encodeWithSelector(
            BoxV1.initialize.selector,
            200, // different initial value
            deployer // initial owner
        );

        BeaconProxy proxy2 = new BeaconProxy(address(beacon), initData2);
        console.log("BeaconProxy 2 deployed at:", address(proxy2));

        // Deploy Proxy 3
        bytes memory initData3 = abi.encodeWithSelector(
            BoxV1.initialize.selector,
            300, // different initial value
            deployer // initial owner
        );

        BeaconProxy proxy3 = new BeaconProxy(address(beacon), initData3);
        console.log("BeaconProxy 3 deployed at:", address(proxy3));

        // Verify the proxies work
        console.log("\n=== Verification ===");
        BoxV1 proxy1Box = BoxV1(address(proxy1));
        BoxV1 proxy2Box = BoxV1(address(proxy2));
        BoxV1 proxy3Box = BoxV1(address(proxy3));

        console.log("Proxy 1 value:", proxy1Box.getValue());
        console.log("Proxy 2 value:", proxy2Box.getValue());
        console.log("Proxy 3 value:", proxy3Box.getValue());
        console.log("Proxy 1 owner:", proxy1Box.getOwner());
        console.log("Proxy 2 owner:", proxy2Box.getOwner());
        console.log("Proxy 3 owner:", proxy3Box.getOwner());

        vm.stopBroadcast();

        console.log("\n=== Deployment Summary ===");
        console.log("Implementation (BoxV1):", address(implementation));
        console.log("UpgradeableBeacon:", address(beacon));
        console.log("BeaconProxy 1:", address(proxy1));
        console.log("BeaconProxy 2:", address(proxy2));
        console.log("BeaconProxy 3:", address(proxy3));
        console.log("\nAll proxies share the same implementation via the beacon!");
        console.log("To upgrade, deploy BoxV2 and call beacon.upgradeTo(newImplementation)");
    }
}
