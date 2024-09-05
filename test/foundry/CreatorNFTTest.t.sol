// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import { CreatorNFT } from "../../contracts/CreatorNFT.sol";
import { IOAppOptionsType3, EnforcedOptionParam } from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OAppOptionsType3.sol";
import { OptionsBuilder } from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "forge-std/console.sol";
import { TestHelperOz5 } from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";
import { IERC6551Registry } from "../../contracts/interfaces/IERC6551Registry.sol";

contract CreatorNFTTest is TestHelperOz5 {
    using OptionsBuilder for bytes;

    uint32 private aEid = 1;
    uint32 private bEid = 2;

    CreatorNFT private aCreatorNFT;
    CreatorNFT private bCreatorNFT;

    address private userA = address(0x1);
    address private userB = address(0x2);
    uint256 private initialBalance = 100 ether;

    address private mockRegistry = address(0x3);
    address private mockPaymentModuleImplementation = address(0x4);

    function setUp() public virtual override {
        vm.deal(userA, 1000 ether);
        vm.deal(userB, 1000 ether);

        super.setUp();
        setUpEndpoints(2, LibraryType.UltraLightNode);

        aCreatorNFT = new CreatorNFT(address(endpoints[aEid]), address(this), mockRegistry, mockPaymentModuleImplementation);
        bCreatorNFT = new CreatorNFT(address(endpoints[bEid]), address(this), mockRegistry, mockPaymentModuleImplementation);

        address[] memory oapps = new address[](2);
        oapps[0] = address(aCreatorNFT);
        oapps[1] = address(bCreatorNFT);
        this.wireOApps(oapps);
    }

    function test_constructor() public {
        assertEq(aCreatorNFT.owner(), address(this));
        assertEq(bCreatorNFT.owner(), address(this));

        assertEq(address(aCreatorNFT.endpoint()), address(endpoints[aEid]));
        assertEq(address(bCreatorNFT.endpoint()), address(endpoints[bEid]));
    }

    function test_quoteDeployPaymentModule() public {
        uint256 tokenId = aCreatorNFT.mint("ipfs://test");
        vm.prank(userA);
        (uint256 nativeFee, uint256 zroFee) = aCreatorNFT.getDeploymentFees(tokenId, bEid, address(0x1234));

        assertGt(nativeFee, 0, "Native fee should be greater than 0");
        assertEq(zroFee, 0, "ZRO fee should be 0");
    }
       function test_deployPaymentModuleCrossChain() public {
        vm.prank(userA);
        uint256 tokenId = aCreatorNFT.mint("ipfs://test");
        vm.prank(userA);
        
        (uint256 nativeFee, ) = aCreatorNFT.getDeploymentFees(tokenId, bEid, address(0x1234));

        vm.expectEmit(true, true, true, true);
        emit CreatorNFT.PaymentModuleDeployed(tokenId, bEid, address(0));

        vm.prank(userA);
        aCreatorNFT.deployPaymentModule{value: nativeFee}(tokenId, bEid, address(0x1234));

        // Simulate the cross-chain message being received
        bytes memory payload = abi.encode(
            aCreatorNFT.DEPLOY_PAYMENT_MODULE(),
            mockRegistry,
            abi.encode(address(0x1234), keccak256(abi.encode(address(aCreatorNFT), tokenId, bEid)), bEid, address(aCreatorNFT), tokenId)
        );

        // vm.expectEmit(true, true, true, true);
        // emit CreatorNFT.PaymentModuleDeployed(tokenId, aEid, address(0x5678));

    //     vm.mockCall(
    //         mockRegistry,
    //         abi.encodeWithSelector(IERC6551Registry.createAccount.selector),
    //         abi.encode(address(0x5678))
    //     );

    //    // bCreatorNFT.lzReceive(aEid, abi.encodePacked(address(aCreatorNFT)), 0, payload, "", 0);

    //     assertEq(bCreatorNFT.paymentModules(tokenId, aEid), address(0x5678), "Payment module should be deployed on chain B");
    }

    function onERC721Received(address,address,uint256,bytes calldata) external returns (bytes4) {
        return 0x150b7a02;
    }
}