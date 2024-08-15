import { ethers, upgrades } from "hardhat";
import { expect } from "chai";
import { Contract } from "ethers";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { AIOracle, AIToken, AIToken__factory } from "../typechain-types";

describe("AIOracle", function () {
  let aiToken: AIToken;
  let aiOracle: AIOracle;
  let owner: HardhatEthersSigner;
  let user: HardhatEthersSigner;

  before(async function () {
    [owner, user] = await ethers.getSigners();

    // Deploy AIToken contract
    const AIToken = (await ethers.getContractFactory(
      "AIToken"
    )) as AIToken__factory;
    aiToken = (await upgrades.deployProxy(
      AIToken,
      [owner.address, owner.address, owner.address],
      { initializer: "initialize" }
    )) as unknown as AIToken;
    await aiToken.waitForDeployment();

    // Mint some AITokens for testing
    await aiToken.mint(user.address, ethers.parseUnits("1000"));

    // Deploy AIOracle contract
    const AIOracle = await ethers.getContractFactory("AIOracle");
    aiOracle = (await upgrades.deployProxy(
      AIOracle,
      [
        await aiToken.getAddress(),
        ["gpt-3.5", "gpt-4o", "dall-e"],
        [
          [
            ["plain:text", "ipfs:json"],
            ["plain:text", "ipfs:img"],
          ],
          [
            ["plain:text", "ipfs:json"],
            ["plain:text", "ipfs:img"],
          ],
          [
            ["plain:text", "ipfs:json"],
            ["plain:text", "ipfs:img"],
          ],
        ],
      ],
      { initializer: "initialize" }
    )) as unknown as AIOracle;
    await aiOracle.waitForDeployment();
  });

  it("should create an AI request", async function () {
    // Approve the AIOracle contract to spend AITokens
    const aiOracleAddress = await aiOracle.getAddress();
    await aiToken
      .connect(user)
      .approve(aiOracleAddress, ethers.parseUnits("100"));

    const tokenLimit = ethers.parseUnits("10");

    await aiOracle.connect(user).depositTokens(ethers.parseUnits("100"));

    // Create an AI request
    const tx = await aiOracle
      .connect(user)
      .createAIRequest(
        ethers.toUtf8Bytes("Test Data"),
        "gpt-3.5",
        "plain:text",
        "plain:text",
        0,
        ethers.ZeroAddress,
        tokenLimit
      );

    expect(tx).to.emit(aiOracle, "AIRequestCreated");
  });

  it("should allow the oracle to submit response segments", async function () {
    const tokenConsumed = ethers.parseUnits("5");

    // Oracle role assignment to the deployer for testing purposes
    await aiOracle
      .connect(owner)
      .grantRole(await aiOracle.RESPONSE_ROLE(), owner.address);

    // Submit response segments
    const tx = await aiOracle.submitAIResponseSegments(
      1,
      [ethers.encodeBytes32String("Segment 1")],
      true,
      tokenConsumed,
      500000 // gas limit
    );

    // Check if the AIResponseReceived event was emitted
    expect(tx).to.emit(aiOracle, "AIResponseReceived");

    // Check if the request was updated correctly
    const request = await aiOracle.requests(1);
    expect(request.isFinalized).to.be.true;
    expect(request.tokenConsumed).to.equal(tokenConsumed);
  });

  it("should allow users to deposit tokens", async function () {
    const amount = ethers.parseUnits("100");
    const initBalance = await aiOracle.getTokenBalance(user.address);

    // Deposit tokens
    const aiOracleAddress = await aiOracle.getAddress();
    await aiToken.connect(user).approve(aiOracleAddress, amount);
    await aiOracle.connect(user).depositTokens(amount);

    // Check if the balance was updated correctly
    const balance = await aiOracle.getTokenBalance(user.address);
    expect(balance).to.equal(amount + initBalance);
  });

  it("should allow users to withdraw tokens", async function () {
    const amount = ethers.parseUnits("50");
    const initBalance = await aiOracle.getTokenBalance(user.address);

    // Withdraw tokens
    await aiOracle.connect(user).withdrawToken(amount);

    // Check if the balance was updated correctly
    const balance = await aiOracle.getTokenBalance(user.address);
    expect(initBalance - balance).to.equal(ethers.parseUnits("50"));
  });
});
