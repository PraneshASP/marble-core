// // SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.25;

// import "forge-std/Script.sol";
// import "../src/CreatorNFT.sol";
// import "../src/PaymentModel.sol";

// contract DeployFuji is Script {
//     function run() external {
//         uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
//         vm.startBroadcast(deployerPrivateKey);

//         // Deploy PaymentModel implementation
//         PaymentModel paymentModelImpl = new PaymentModel();
//         console.log("PaymentModel implementation deployed to:", address(paymentModelImpl));

//         // ERC6551 Registry address
//         address ERC6551_REGISTRY = 0x000000006551c19487814612e58FE06813775758;

//         // Deploy CreatorNFT
//         CreatorNFT creatorNFT = new CreatorNFT(address(paymentModelImpl), ERC6551_REGISTRY);
//         console.log("CreatorNFT deployed to:", address(creatorNFT));

//         // // Mint an NFT
//         // uint256 tokenId = creatorNFT.mint("ipfs://example");
//         // console.log("NFT minted with tokenId:", tokenId);

//         // // Deploy PaymentModel and create subscription tires
//         // creatorNFT.deployPaymentModel(tokenId);
//         // console.log("PaymentModel deployed for tokenId:", tokenId);

//         // address[] memory paymentModels = creatorNFT.getPaymentModels(tokenId);
//         // address deployedPaymentModelAddress = paymentModels[0];
//         // console.log("Deployed PaymentModel address:", deployedPaymentModelAddress);

//         // PaymentModel deployedPaymentModel = PaymentModel(payable(deployedPaymentModelAddress));
//         // deployedPaymentModel.createTier(0.1 ether, 30 days); // 0.1 AVAX for 30 days
//         // console.log("Subscription tier created");

//         vm.stopBroadcast();

//         console.log("Deployment and setup complete!");
//     }
// }
