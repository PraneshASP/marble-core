// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Script.sol";
import "../src/CreatorNFT.sol";
import "../src/PaymentModel.sol";
import { IERC721Receiver } from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract DeployCrossChain is Script {
    // Fuji (Avalanche testnet) chain ID
    uint32 constant FUJI_CHAIN_ID = 43113;
    // Base Sepolia chain ID
    uint32 constant BASE_SEPOLIA_CHAIN_ID = 84532;

    address constant LAYER_ZERO_EXECUTOR = 0x0F220412Bf22E05EBcC5070D60fd7136A08aF22C;
    address constant ERC6551_REGISTRY = 0x000000006551c19487814612e58FE06813775758;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Deploy on Fuji
      //  vm.startBroadcast(deployerPrivateKey);
        uint256 fujiId = vm.createFork(vm.rpcUrl("fuji"));
        vm.selectFork(fujiId);
        PaymentModel fujiPaymentModelImpl = new PaymentModel();

        CreatorNFT fujiCreatorNFT = new CreatorNFT(
            ERC6551_REGISTRY,
            LAYER_ZERO_EXECUTOR,
            address(fujiPaymentModelImpl)
        );

        // Mint NFT
        uint256 tokenId = fujiCreatorNFT.mint("ipfs://example");

        // vm.stopBroadcast();

        // // Deploy on Base Sepolia
      //  vm.startBroadcast(deployerPrivateKey);
        vm.createSelectFork(vm.rpcUrl("base_sep"));
        
        PaymentModel baseSepoliaPaymentModelImpl = new PaymentModel();

        // // Deploy PaymentModule cross-chain
        vm.createSelectFork(vm.rpcUrl("fuji"));
        fujiCreatorNFT.deployPaymentModule{value: 1 ether}(
            tokenId,
            BASE_SEPOLIA_CHAIN_ID,
            address(baseSepoliaPaymentModelImpl)
        );

        // vm.stopBroadcast();

        // // Verify token() function
        vm.createSelectFork(vm.rpcUrl("base_sep"));
        address paymentModuleAddress = fujiCreatorNFT.paymentModules(tokenId, BASE_SEPOLIA_CHAIN_ID);
        PaymentModel paymentModule = PaymentModel(payable(paymentModuleAddress));

        (uint256 chainId, address tokenContract, uint256 returnedTokenId) = paymentModule.token();

        console.log("Verification Results:");
        console.log("Expected Chain ID:", FUJI_CHAIN_ID);
        console.log("Actual Chain ID:", chainId);
        console.log("Expected Token Contract:", address(fujiCreatorNFT));
        console.log("Actual Token Contract:", tokenContract);
        console.log("Expected Token ID:", tokenId);
        console.log("Actual Token ID:", returnedTokenId);

        require(chainId == FUJI_CHAIN_ID, "Incorrect Chain ID");
        require(tokenContract == address(fujiCreatorNFT), "Incorrect Token Contract");
        require(returnedTokenId == tokenId, "Incorrect Token ID");

        console.log("Verification successful!");
    }

    function onERC721Received(address _operator, address _from, uint256 _id, bytes calldata _data)
        public
        virtual
        returns (bytes4)
    {

        return IERC721Receiver.onERC721Received.selector;
    }
}