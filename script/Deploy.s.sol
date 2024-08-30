// // SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.13;

// import "forge-std/Script.sol";
// import "../src/CreatorNFT.sol";
// import "../src/POUFPaymentModel.sol";

// contract DeployScript is Script {
//     function setUp() public {}

//     function run() public {
//         uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
//         vm.startBroadcast(deployerPrivateKey);

//          CreatorNFT creatorNFT = new CreatorNFT();

//          uint256 tokenId = creatorNFT.mintCreatorToken("");

//          uint256 subscriptionPrice = 0.1 ether;
//         POUFPaymentModel paymentModel = new POUFPaymentModel(address(creatorNFT), tokenId, subscriptionPrice);

//          creatorNFT.addPaymentModel(tokenId, address(paymentModel));

//         vm.stopBroadcast();

//         console.log("CreatorNFT deployed at:", address(creatorNFT));
//         console.log("PaymentModel deployed at:", address(paymentModel));
//         console.log("Creator Token ID:", tokenId);
//     }
// }
