import { ethers, defender } from "hardhat";

const AI_TOKEN_ADDRESS = "0x88B6e8866A6975AdC0888B19661d630EB03841D6";

async function main() {
  const OracleFactory = await ethers.getContractFactory("AIOracle");
  const aiTokenAddress = ethers.getAddress(AI_TOKEN_ADDRESS);
  const aiOracle = await defender.deployProxy(OracleFactory, [
    aiTokenAddress,
    ["gpt-3.5", "dall-e"],
    [
      [
        ["plain:text", "ipfs:text", "url:text"],
        ["palin:text", "ipfs:text", "url:text"],
      ],
      [
        ["plain:text", "ipfs:text", "url:text"],
        ["ipfs:img", "url:img"],
      ],
    ],
  ]);
  await aiOracle.waitForDeployment();
  console.log("AIOracle deployed at: ", await aiOracle.getAddress());
}

main();
