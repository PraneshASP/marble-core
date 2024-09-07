// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import { CreatorNFT } from "../../contracts/CreatorNFT.sol";
import { CustomRegistry } from "../../contracts/CustomRegistry.sol";
import { IOAppOptionsType3, EnforcedOptionParam } from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OAppOptionsType3.sol";
import { OptionsBuilder } from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "forge-std/console.sol";
import { TestHelperOz5 } from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";
import { IERC6551Registry } from "../../contracts/interfaces/IERC6551Registry.sol";
import { AddressCast } from "@layerzerolabs/lz-evm-protocol-v2/contracts/libs/AddressCast.sol";
import { Origin } from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import { PaymentModel } from "contracts/PaymentModel.sol";

contract CreatorNFTTest is TestHelperOz5 {
    using OptionsBuilder for bytes;

    uint32 private aEid = 1;
    uint32 private bEid = 2;

    CreatorNFT private aCreatorNFT;
    CustomRegistry private aRegistry;
    CustomRegistry private bRegistry;

    address private userA = address(0x1);
    address private userB = address(0x2);
    uint256 private initialBalance = 100 ether;

    address private paymentModuleImpl;

    function setUp() public virtual override {
        vm.deal(userA, 1000 ether);
        vm.deal(userB, 1000 ether);

        super.setUp();
        setUpEndpoints(2, LibraryType.UltraLightNode);

        // Deploy CustomRegistry on both chains
        aRegistry = new CustomRegistry(address(endpoints[aEid]), address(this));
        bRegistry = new CustomRegistry(address(endpoints[bEid]), address(this));

        // Deploy the payment module
        paymentModuleImpl = address(new PaymentModel());

        // Deploy CreatorNFT only on chain A
        aCreatorNFT = new CreatorNFT(address(endpoints[aEid]), address(this), address(aRegistry), paymentModuleImpl);

        // Wire OApps
        address[] memory oapps = new address[](3);
        oapps[0] = address(aCreatorNFT);
        oapps[1] = address(aRegistry);
        oapps[2] = address(bRegistry);
        this.wireOApps(oapps);

        // Set peers for CreatorNFT and CustomRegistry
        aCreatorNFT.setPeer(bEid, AddressCast.toBytes32(address(bRegistry)));
        aRegistry.setPeer(bEid, AddressCast.toBytes32(address(bRegistry)));
        bRegistry.setPeer(aEid, AddressCast.toBytes32(address(aRegistry)));
    }

    function test_crossChainDeployPaymentModule() public {
        // Mint an NFT on chain A
        vm.prank(userA);
        uint256 tokenId = aCreatorNFT.mint("ipfs://test");

        // Get deployment fees
        (uint256 nativeFee, ) = aCreatorNFT.getDeploymentFees(tokenId, bEid, paymentModuleImpl);

        // Deploy payment module cross-chain
        vm.prank(userA);
        vm.expectEmit(true, true, true, true);
        emit CreatorNFT.PaymentModuleDeployed(tokenId, bEid, address(0));
        aCreatorNFT.deployPaymentModule{value: nativeFee}(tokenId, bEid, paymentModuleImpl);

        // Simulate the cross-chain message being received and processed on chain B
        bytes memory payload = abi.encode(
            paymentModuleImpl,
            keccak256(abi.encode(address(aCreatorNFT), tokenId, bEid)),
            bEid,
            address(aCreatorNFT),
            tokenId
        );

        // Create the Origin struct
         Origin memory origin = Origin({
            srcEid: aEid,
            sender: AddressCast.toBytes32(address(aRegistry)),
            nonce: 1 // You might want to use an actual nonce here
        });

        vm.prank(address(endpoints[bEid]));
        bRegistry.lzReceive(
            origin,
            bytes32(0), // _guid
            payload,
            address(0), // _executor
            "" // _extraData
        );


        // Verify the payment module was deployed on chain B
        bytes32 salt = keccak256(abi.encode(address(aCreatorNFT), tokenId, bEid));
      

        address expectedPaymentModule = bRegistry.getPaymentModule(bEid, tokenId, address(aCreatorNFT));
        assertTrue(expectedPaymentModule != address(0), "Payment module should be deployed on chain B");

        // Verify the payment module details
        (uint256 chainId, address tokenContract, uint256 deployedTokenId) = PaymentModel(payable(expectedPaymentModule)).token();
        assertEq(chainId, bEid, "Incorrect chain ID");
        assertEq(tokenContract, address(aCreatorNFT), "Incorrect token contract address");
        assertEq(deployedTokenId, tokenId, "Incorrect token ID");
    }

       function test_createTier() public {
        // Mint an NFT and deploy payment module
        vm.prank(userA);
        uint256 tokenId = aCreatorNFT.mint("ipfs://test");
        (uint256 nativeFee, ) = aCreatorNFT.getDeploymentFees(tokenId, bEid, paymentModuleImpl);
        vm.prank(userA);
        aCreatorNFT.deployPaymentModule{value: nativeFee}(tokenId, bEid, paymentModuleImpl);

        // Simulate cross-chain message processing
        bytes memory payload = abi.encode(
            paymentModuleImpl,
            keccak256(abi.encode(address(aCreatorNFT), tokenId, bEid)),
            bEid,
            address(aCreatorNFT),
            tokenId
        );
        Origin memory origin = Origin({
            srcEid: aEid,
            sender: AddressCast.toBytes32(address(aRegistry)),
            nonce: 1
        });
        vm.prank(address(endpoints[bEid]));
        bRegistry.lzReceive(origin, bytes32(0), payload, address(0), "");

        // Get the deployed payment module address
        address paymentModule = bRegistry.getPaymentModule(bEid, tokenId, address(aCreatorNFT));

        // Create a tier
        uint256 price = 0.1 ether;
        uint256 duration = 30 days;
        vm.prank(userA);
        PaymentModel(payable(paymentModule)).createTier(price, duration);

        // Verify tier creation
        (uint256 tierPrice, uint256 tierDuration, bool isActive) = PaymentModel(payable(paymentModule)).subscriptionTiers(1);
        assertEq(tierPrice, price, "Incorrect tier price");
        assertEq(tierDuration, duration, "Incorrect tier duration");
        assertTrue(isActive, "Tier should be active");
    }

    function test_subscribe() public {
        // Set up NFT, payment module, and tier (reusing code from test_createTier)
        vm.prank(userA);
        uint256 tokenId = aCreatorNFT.mint("ipfs://test");
        (uint256 nativeFee, ) = aCreatorNFT.getDeploymentFees(tokenId, bEid, paymentModuleImpl);
        vm.prank(userA);
        aCreatorNFT.deployPaymentModule{value: nativeFee}(tokenId, bEid, paymentModuleImpl);

        // Simulate cross-chain message processing
        bytes memory payload = abi.encode(
            paymentModuleImpl,
            keccak256(abi.encode(address(aCreatorNFT), tokenId, bEid)),
            bEid,
            address(aCreatorNFT),
            tokenId
        );
        Origin memory origin = Origin({
            srcEid: aEid,
            sender: AddressCast.toBytes32(address(aRegistry)),
            nonce: 1
        });
        vm.prank(address(endpoints[bEid]));
        bRegistry.lzReceive(origin, bytes32(0), payload, address(0), "");

        address paymentModule = bRegistry.getPaymentModule(bEid, tokenId, address(aCreatorNFT));
        vm.prank(userA);
        PaymentModel(payable(paymentModule)).createTier(0.1 ether, 30 days);

        // Subscribe to the tier
        vm.prank(userB);
        PaymentModel(payable(paymentModule)).subscribe{value: 0.1 ether}(1);

        // Verify subscription
        assertTrue(PaymentModel(payable(paymentModule)).isSubscribed(userB), "User B should be subscribed");

        (uint256 subTierId, uint256 startTime, uint256 endTime) = PaymentModel(payable(paymentModule)).getSubscriptionDetails(userB);
        assertEq(subTierId, 1, "Incorrect subscription tier ID");
        assertEq(endTime - startTime, 30 days, "Incorrect subscription duration");
    }

    function onERC721Received(address,address,uint256,bytes calldata) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
