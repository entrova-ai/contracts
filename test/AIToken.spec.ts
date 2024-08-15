import { expect } from "chai";
import { ethers, upgrades } from "hardhat";
import { Contract } from "ethers";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { AIToken__factory } from "../typechain-types/factories/contracts/AIToken__factory";

describe("AIToken", function () {
  let Token: AIToken__factory;
  let token: Contract;
  let owner: HardhatEthersSigner;
  let addr1: HardhatEthersSigner;
  let addr2: HardhatEthersSigner;

  beforeEach(async function () {
    [owner, addr1, addr2] = await ethers.getSigners();

    // Deploying the contract using UUPS proxy pattern
    Token = await ethers.getContractFactory("AIToken");
    token = await upgrades.deployProxy(
      Token,
      [owner.address, owner.address, owner.address],
      {
        initializer: "initialize",
      }
    );
    await token.waitForDeployment();
  });

  it("Should have the correct name and symbol and decimals", async function () {
    expect(await token.name()).to.equal("AIToken");
    expect(await token.symbol()).to.equal("AIT");
    expect(await token.decimals()).to.equal(18);
  });

  it("Should assign the total supply of tokens to the owner", async function () {
    const ownerBalance = await token.balanceOf(owner.address);
    expect(await token.totalSupply()).to.equal(ownerBalance);
  });

  it("Should allow the owner to mint tokens", async function () {
    await token.mint(owner.address, ethers.parseUnits("1000", 18));
    expect(await token.totalSupply()).to.equal(ethers.parseUnits("1000", 18));
    expect(await token.balanceOf(owner.address)).to.equal(
      ethers.parseUnits("1000", 18)
    );
  });

  it("Should allow the owner to burn tokens", async function () {
    await token.mint(owner.address, ethers.parseUnits("1000", 18));
    await token.burn(ethers.parseUnits("500", 18));
    expect(await token.totalSupply()).to.equal(ethers.parseUnits("500", 18));
    expect(await token.balanceOf(owner.address)).to.equal(
      ethers.parseUnits("500", 18)
    );
  });

  it("Should allow token transfers between accounts", async function () {
    await token.mint(owner.address, ethers.parseUnits("1000", 18));
    await token.transfer(addr1.address, ethers.parseUnits("500", 18));
    expect(await token.balanceOf(owner.address)).to.equal(
      ethers.parseUnits("500", 18)
    );
    expect(await token.balanceOf(addr1.address)).to.equal(
      ethers.parseUnits("500", 18)
    );
  });

  it("Should upgrade the token contract", async function () {
    const TokenV2 = await ethers.getContractFactory("MockAIToken");
    const tokenAddress = await token.getAddress();
    const tokenV2 = await upgrades.upgradeProxy(tokenAddress, TokenV2);

    expect(await tokenV2.version()).to.equal("v2");
  });
});
