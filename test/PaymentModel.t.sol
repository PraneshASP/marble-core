// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import { Test, console2 } from "forge-std/Test.sol";
import { PaymentModel } from "../src/PaymentModel.sol";
import { CreatorNFT } from "../src/CreatorNFT.sol";
import { IERC6551Registry } from "../src/interfaces/IERC6551Registry.sol";

contract PaymentModelTest is Test {
    PaymentModel public paymentModelImpl;
    CreatorNFT public creatorNFT;
    IERC6551Registry public erc6551Registry;

    address constant ERC6551_REGISTRY = 0x000000006551c19487814612e58FE06813775758;
    uint256 constant FORK_BLOCK_NUMBER = 19_102_649;
    string constant BASE_RPC_URL = "https://mainnet.base.org";

    address public creator;
    address public user;

    function setUp() public {
        // Fork Base network
        vm.createSelectFork(BASE_RPC_URL, FORK_BLOCK_NUMBER);

        // Set up addresses
        creator = makeAddr("creator");
        user = makeAddr("user");

        paymentModelImpl = new PaymentModel();

        erc6551Registry = IERC6551Registry(ERC6551_REGISTRY);

        creatorNFT = new CreatorNFT(address(paymentModelImpl), address(erc6551Registry));
    }

    function test_CreatorFlow() public {
        vm.startPrank(creator);
        uint256 tokenId = creatorNFT.mint("ipfs://example");
        assertEq(creatorNFT.ownerOf(tokenId), creator);

        //creatorNFT.deployPaymentModel(tokenId);

        address[] memory paymentModels = creatorNFT.getPaymentModels(tokenId);
        assertEq(paymentModels.length, 1);
        address paymentModelAddress = paymentModels[0];

        PaymentModel deployedPaymentModel = PaymentModel(payable(paymentModelAddress));
        uint256 tierPrice = 0.1 ether;
        uint256 tierDuration = 30 days;
        deployedPaymentModel.createTier(tierPrice, tierDuration);

        (uint256 price, uint256 duration, bool isActive) = deployedPaymentModel.subscriptionTiers(1);
        assertEq(price, tierPrice);
        assertEq(duration, tierDuration);
        assertTrue(isActive);

        vm.stopPrank();
    }

    function test_UserFlow() public {
        test_CreatorFlow();

        address[] memory paymentModels = creatorNFT.getPaymentModels(0);
        address paymentModelAddress = paymentModels[0];
        PaymentModel deployedPaymentModel = PaymentModel(payable(paymentModelAddress));

        vm.startPrank(user);
        vm.deal(user, 1 ether);

        deployedPaymentModel.subscribe{ value: 0.1 ether }(1);

        assertTrue(deployedPaymentModel.isSubscribed(user));
        (uint256 tierId, uint256 startTime, uint256 endTime) = deployedPaymentModel.getSubscriptionDetails(user);
        assertEq(tierId, 1);
        assertEq(endTime, startTime + 30 days);

        assertTrue(creatorNFT.isSubscribed(0, user));
        CreatorNFT.SubscriptionDetails memory subDetails = creatorNFT.getSubscriptionDetails(0, user);
        assertEq(subDetails.paymentModel, address(deployedPaymentModel));
        assertEq(subDetails.tierId, 1);
        assertEq(subDetails.endTime, startTime + 30 days);

        vm.stopPrank();
    }

    function test_FailedSubscription() public {
        test_CreatorFlow();

        address[] memory paymentModels = creatorNFT.getPaymentModels(0);
        address paymentModelAddress = paymentModels[0];
        PaymentModel deployedPaymentModel = PaymentModel(payable(paymentModelAddress));

        vm.startPrank(user);
        vm.deal(user, 0.05 ether);

        vm.expectRevert(PaymentModel.InvalidAmount.selector);
        deployedPaymentModel.subscribe{ value: 0.05 ether }(1);

        assertFalse(deployedPaymentModel.isSubscribed(user));
        assertFalse(creatorNFT.isSubscribed(0, user));

        vm.stopPrank();
    }
}
