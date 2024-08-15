import { ethers, defender } from "hardhat";

async function main() {
  const AITokenFactory = await ethers.getContractFactory("AIToken");
  const signers = await ethers.getSigners();
  const currentSigner = signers[0];
  const msgSender = currentSigner.address;
  const aiToken = await defender.deployProxy(AITokenFactory, [
    msgSender,
    msgSender,
    msgSender,
  ]);
  await aiToken.waitForDeployment();
  console.log("AIToken deployed at: ", await aiToken.getAddress());
}

main();
