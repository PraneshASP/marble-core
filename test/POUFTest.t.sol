// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {POUFPaymentModel} from "../src/POUFPaymentModel.sol";
import {CreatorNFT} from "../src/CreatorNFT.sol";
import {IERC6551Registry} from "../src/interfaces/IERC6551Registry.sol";

contract POUFTest is Test {
    POUFPaymentModel public poufPaymentModelImpl;
    CreatorNFT public creatorNFT;
    IERC6551Registry public erc6551Registry;

    address constant ERC6551_REGISTRY = 0x000000006551c19487814612e58FE06813775758;
    uint256 constant FORK_BLOCK_NUMBER = 19102649;  
    string constant BASE_RPC_URL = "https://mainnet.base.org";  

    address public creator;
    address public user;

    function setUp() public {
        // Fork Base network
        vm.createSelectFork(BASE_RPC_URL, FORK_BLOCK_NUMBER);

        // Set up addresses
        creator = makeAddr("creator");
        user = makeAddr("user");

        // Deploy POUFPaymentModel implementation
        poufPaymentModelImpl = new POUFPaymentModel();

        // Set up ERC6551Registry interface
        erc6551Registry = IERC6551Registry(ERC6551_REGISTRY);

        // Deploy CreatorNFT
        creatorNFT = new CreatorNFT(address(poufPaymentModelImpl), address(erc6551Registry));
    }

    function test_CreatorFlow() public {
        // 1. Creator mints an NFT
        vm.startPrank(creator);
        uint256 tokenId = creatorNFT.mint("ipfs://example");
        assertEq(creatorNFT.ownerOf(tokenId), creator);

        // 2. Creator deploys POUFPaymentModel
        uint256 subscriptionPrice = 0.1 ether;
        creatorNFT.deployPOUFPaymentModel(tokenId, subscriptionPrice);

        // Get the deployed payment model address
        address[] memory paymentModels = creatorNFT.getPaymentModels(tokenId);
        assertEq(paymentModels.length, 1);
        address paymentModelAddress = paymentModels[0];

        // Verify the payment model is set up correctly
        POUFPaymentModel deployedPaymentModel = POUFPaymentModel(payable(paymentModelAddress));
        (uint256 chainId, address tokenContract, uint256 nftTokenId) = deployedPaymentModel.token();
        assertEq(chainId, block.chainid);
        assertEq(tokenContract, address(creatorNFT));
        assertEq(nftTokenId, tokenId);

        vm.stopPrank();
    }

    function test_UserFlow() public {
        // set up the creator flow first
        test_CreatorFlow();

        // Get the deployed payment model address
        address[] memory paymentModels = creatorNFT.getPaymentModels(0);  
        address paymentModelAddress = paymentModels[0];
        POUFPaymentModel deployedPaymentModel = POUFPaymentModel(payable(paymentModelAddress));

         vm.startPrank(user);
        vm.deal(user, 1 ether);  

        // User subscribes
        deployedPaymentModel.subscribe{value: 0.1 ether}();

        assertTrue(deployedPaymentModel.isSubscribed(user));
        assertEq(address(deployedPaymentModel).balance, 0.1 ether);

        vm.stopPrank();
    }

    function test_FailedSubscription() public {
        test_CreatorFlow();

        // Get the deployed payment model address
        address[] memory paymentModels = creatorNFT.getPaymentModels(0);  
        address paymentModelAddress = paymentModels[0];
        POUFPaymentModel deployedPaymentModel = POUFPaymentModel(payable(paymentModelAddress));

        vm.startPrank(user);
        vm.deal(user, 0.05 ether);  

        // User tries to subscribe with insufficient funds
        vm.expectRevert(POUFPaymentModel.InvalidAmount.selector);
        deployedPaymentModel.subscribe{value: 0.05 ether}();

        // Verify the subscription failed
        assertFalse(deployedPaymentModel.isSubscribed(user));
        assertEq(address(deployedPaymentModel).balance, 0);

        vm.stopPrank();
    }
}
