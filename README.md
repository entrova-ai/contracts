# AI Oracle

Welcome to the **AI Oracle** project, a Solidity-based decentralized AI oracle system that allows seamless interaction between blockchain and powerful off-chain AI models, such as LLMs (Large Language Models) and AI image generation models. 

This project includes two core smart contracts:

1. **AIOracle.sol**: The Oracle contract for facilitating requests to off-chain AI services and returning results to the blockchain.
2. **AIToken.sol**: The utility token contract used to pay for AI Oracle services.

## Features

- **AI Integration**: Users can interact with off-chain AI models for tasks like language processing or image generation via the AI Oracle.
- **Tokenized Payment**: Payments for AI services are made using `AIToken`, ensuring a seamless and blockchain-native experience.
- **Data Flexibility**: Results can be returned in multiple formats, including plain text, IPFS, and URLs, enabling a variety of use cases.
- **On-Chain Results**: Responses from the AI models are stored back on-chain, maintaining transparency and accessibility.

---

## Contracts Overview

### AIOracle.sol
The core contract acts as a bridge between blockchain and off-chain AI systems. It handles the following:

- **AI Request Management**: Accepts user requests and emits events for off-chain services to process.
- **Response Handling**: Allows off-chain services to submit AI responses, which are then recorded on-chain.
- **Data Formats**: Supports multiple response formats, such as plain text, IPFS URLs, and more.

### AIToken.sol
A utility token based on the ERC20 standard, `AIToken` is used to pay for oracle services. It includes features such as:

- **Mintable and Burnable**: Administrators can mint tokens as needed and burn them when consumed.
- **Upgradeable**: Built with UUPS upgradeability for future enhancements.
- **OpenZeppelin Integration**: Utilizes OpenZeppelin libraries for secure implementation.

---

## How It Works

1. **Token Deposit**: Users deposit `AIToken` to the Oracle contract to pay for AI services.
2. **AI Request**: Users submit requests specifying the desired AI model and data type.
3. **Event Emission**: The Oracle emits an event with request details, which is picked up by an off-chain service.
4. **Off-Chain Processing**: The off-chain service interacts with AI models to process the request and prepares the result.
5. **Response Submission**: The result is submitted back to the Oracle contract, where it is recorded on-chain.

---

## Supported Models and Data Types

### Supported AI Models
- **gpt-3.5**: For natural language processing.
- **gpt-4o**: Advanced LLM for more complex tasks.
- **dall-e**: AI-powered image generation.

### Supported Data Types
- `plain:text`
- `plain:json`
- `ipfs:text`
- `ipfs:json`
- `ipfs:img`
- `url:text`
- `url:json`
- `url:img`

---

## Prerequisites
- Solidity 
- OpenZeppelin libraries for ERC20 and UUPS functionality.
- A blockchain development environment like Hardhat.