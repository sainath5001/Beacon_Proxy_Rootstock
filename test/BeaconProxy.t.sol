// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Test, console} from "forge-std/Test.sol";
import {BoxV1} from "../src/BoxV1.sol";
import {BoxV2} from "../src/BoxV2.sol";
import {UpgradeableBeacon} from "openzeppelin-contracts/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {BeaconProxy} from "openzeppelin-contracts/contracts/proxy/beacon/BeaconProxy.sol";
import {IBeacon} from "openzeppelin-contracts/contracts/proxy/beacon/IBeacon.sol";

/**
 * @title BeaconProxyTest
 * @dev Comprehensive tests for Beacon Proxy Pattern
 */
contract BeaconProxyTest is Test {
    BoxV1 public implementationV1;
    BoxV2 public implementationV2;
    UpgradeableBeacon public beacon;
    BeaconProxy public proxy1;
    BeaconProxy public proxy2;
    BeaconProxy public proxy3;

    address public owner = address(0x1);
    address public user = address(0x2);

    uint256 public constant INITIAL_VALUE_1 = 100;
    uint256 public constant INITIAL_VALUE_2 = 200;
    uint256 public constant INITIAL_VALUE_3 = 300;

    function setUp() public {
        // Deploy implementation V1
        implementationV1 = new BoxV1();

        // Deploy beacon with V1 implementation
        beacon = new UpgradeableBeacon(address(implementationV1), owner);

        // Prepare initialization data for proxies
        bytes memory initData1 = abi.encodeWithSelector(BoxV1.initialize.selector, INITIAL_VALUE_1, owner);

        bytes memory initData2 = abi.encodeWithSelector(BoxV1.initialize.selector, INITIAL_VALUE_2, owner);

        bytes memory initData3 = abi.encodeWithSelector(BoxV1.initialize.selector, INITIAL_VALUE_3, owner);

        // Deploy multiple proxies pointing to the same beacon
        proxy1 = new BeaconProxy(address(beacon), initData1);
        proxy2 = new BeaconProxy(address(beacon), initData2);
        proxy3 = new BeaconProxy(address(beacon), initData3);
    }

    function test_InitialDeployment() public view {
        // Check beacon implementation
        assertEq(beacon.implementation(), address(implementationV1));
        assertEq(beacon.owner(), owner);

        // Check proxy values are independent
        BoxV1 box1 = BoxV1(address(proxy1));
        BoxV1 box2 = BoxV1(address(proxy2));
        BoxV1 box3 = BoxV1(address(proxy3));

        assertEq(box1.getValue(), INITIAL_VALUE_1);
        assertEq(box2.getValue(), INITIAL_VALUE_2);
        assertEq(box3.getValue(), INITIAL_VALUE_3);

        // Check all proxies share the same implementation via beacon
        assertEq(box1.getOwner(), owner);
        assertEq(box2.getOwner(), owner);
        assertEq(box3.getOwner(), owner);
    }

    function test_MultipleProxiesShareImplementation() public {
        BoxV1 box1 = BoxV1(address(proxy1));
        BoxV1 box2 = BoxV1(address(proxy2));
        BoxV1 box3 = BoxV1(address(proxy3));

        // All proxies can call functions from the same implementation
        vm.prank(owner);
        box1.setValue(111);

        vm.prank(owner);
        box2.setValue(222);

        vm.prank(owner);
        box3.setValue(333);

        assertEq(box1.getValue(), 111);
        assertEq(box2.getValue(), 222);
        assertEq(box3.getValue(), 333);
    }

    function test_IndependentStorage() public {
        BoxV1 box1 = BoxV1(address(proxy1));
        BoxV1 box2 = BoxV1(address(proxy2));

        // Each proxy maintains independent storage
        vm.prank(owner);
        box1.setValue(999);

        // Proxy2 value should remain unchanged
        assertEq(box2.getValue(), INITIAL_VALUE_2);
        assertEq(box1.getValue(), 999);
    }

    function test_OnlyOwnerCanSetValue() public {
        BoxV1 box1 = BoxV1(address(proxy1));

        // Non-owner cannot set value
        vm.prank(user);
        vm.expectRevert("BoxV1: caller is not the owner");
        box1.setValue(999);

        // Owner can set value
        vm.prank(owner);
        box1.setValue(999);
        assertEq(box1.getValue(), 999);
    }

    function test_UpgradeBeaconToV2() public {
        // Deploy V2 implementation
        implementationV2 = new BoxV2();

        // Upgrade the beacon
        vm.prank(owner);
        beacon.upgradeTo(address(implementationV2));

        assertEq(beacon.implementation(), address(implementationV2));

        // All proxies should now use V2 implementation
        // But they still maintain their V1 state
        BoxV2 box1 = BoxV2(address(proxy1));
        BoxV2 box2 = BoxV2(address(proxy2));
        BoxV2 box3 = BoxV2(address(proxy3));

        // Values should be preserved
        assertEq(box1.getValue(), INITIAL_VALUE_1);
        assertEq(box2.getValue(), INITIAL_VALUE_2);
        assertEq(box3.getValue(), INITIAL_VALUE_3);

        // Migrate to V2 features
        box1.migrateToV2();
        box2.migrateToV2();
        box3.migrateToV2();

        // Now V2 functions should work
        assertEq(box1.getVersion(), 2);
        assertEq(box2.getVersion(), 2);
        assertEq(box3.getVersion(), 2);
    }

    function test_V2NewFeatures() public {
        // Upgrade to V2
        implementationV2 = new BoxV2();
        vm.prank(owner);
        beacon.upgradeTo(address(implementationV2));

        BoxV2 box1 = BoxV2(address(proxy1));
        box1.migrateToV2();

        // Test new V2 features
        vm.prank(owner);
        box1.increment();
        assertEq(box1.getValue(), INITIAL_VALUE_1 + 1);

        vm.prank(owner);
        box1.increment();
        assertEq(box1.getValue(), INITIAL_VALUE_1 + 2);

        // Test history
        assertEq(box1.getHistoryCount(), 3); // initial + 2 increments
        assertEq(box1.getValueFromHistory(0), INITIAL_VALUE_1);
        assertEq(box1.getValueFromHistory(1), INITIAL_VALUE_1 + 1);
        assertEq(box1.getValueFromHistory(2), INITIAL_VALUE_1 + 2);
    }

    function test_OnlyBeaconOwnerCanUpgrade() public {
        implementationV2 = new BoxV2();

        // Non-owner cannot upgrade
        vm.prank(user);
        vm.expectRevert();
        beacon.upgradeTo(address(implementationV2));

        // Owner can upgrade
        vm.prank(owner);
        beacon.upgradeTo(address(implementationV2));
        assertEq(beacon.implementation(), address(implementationV2));
    }

    function test_UpgradePreservesStorage() public {
        BoxV1 box1 = BoxV1(address(proxy1));

        // Set some values before upgrade
        vm.prank(owner);
        box1.setValue(555);

        // Upgrade to V2
        implementationV2 = new BoxV2();
        vm.prank(owner);
        beacon.upgradeTo(address(implementationV2));

        BoxV2 box1V2 = BoxV2(address(proxy1));

        // Value should be preserved
        assertEq(box1V2.getValue(), 555);

        // Owner should be preserved
        assertEq(box1V2.getOwner(), owner);
    }

    function test_TransferOwnership() public {
        BoxV1 box1 = BoxV1(address(proxy1));
        address newOwner = address(0x3);

        vm.prank(owner);
        box1.transferOwnership(newOwner);

        assertEq(box1.getOwner(), newOwner);

        // Old owner cannot set value
        vm.prank(owner);
        vm.expectRevert("BoxV1: caller is not the owner");
        box1.setValue(999);

        // New owner can set value
        vm.prank(newOwner);
        box1.setValue(999);
        assertEq(box1.getValue(), 999);
    }

    function test_AllProxiesUpgradeSimultaneously() public {
        BoxV1 box1 = BoxV1(address(proxy1));
        BoxV1 box2 = BoxV1(address(proxy2));
        BoxV1 box3 = BoxV1(address(proxy3));

        // Set different values
        vm.prank(owner);
        box1.setValue(1000);
        vm.prank(owner);
        box2.setValue(2000);
        vm.prank(owner);
        box3.setValue(3000);

        // Upgrade beacon
        implementationV2 = new BoxV2();
        vm.prank(owner);
        beacon.upgradeTo(address(implementationV2));

        // All proxies immediately get new implementation
        BoxV2 box1V2 = BoxV2(address(proxy1));
        BoxV2 box2V2 = BoxV2(address(proxy2));
        BoxV2 box3V2 = BoxV2(address(proxy3));

        // Values preserved
        assertEq(box1V2.getValue(), 1000);
        assertEq(box2V2.getValue(), 2000);
        assertEq(box3V2.getValue(), 3000);

        // All can use V2 features after migration
        box1V2.migrateToV2();
        box2V2.migrateToV2();
        box3V2.migrateToV2();

        // Test V2 features on all
        vm.prank(owner);
        box1V2.increment(); // 1000 -> 1001
        vm.prank(owner);
        box2V2.decrement(); // 2000 -> 1999
        vm.prank(owner);
        box3V2.increment(); // 3000 -> 3001

        assertEq(box1V2.getValue(), 1001);
        assertEq(box2V2.getValue(), 1999);
        assertEq(box3V2.getValue(), 3001);
    }
}
