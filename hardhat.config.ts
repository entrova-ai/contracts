import "dotenv/config";
import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@openzeppelin/hardhat-upgrades";

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.24",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
      viaIR: true,
    },
  },
  networks: {
    sepolia: {
      accounts: [process.env.PRIVATE_KEY!],
      url: process.env.URL!,
    },
  },
  defender: {
    apiKey: process.env.API_KEY!,
    apiSecret: process.env.API_SECRET!,
  },
};

export default config;
