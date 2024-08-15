// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

library AIOracleValidationLib {
    function requireTokenLimit(
        uint256 tokenLimit,
        uint256 minTokenLimit
    ) internal pure {
        require(
            tokenLimit >= minTokenLimit,
            "Token limit is below the minimum required."
        );
    }

    function requireBalance(
        uint256 balance,
        uint256 requiredAmount,
        uint256 freezeBalance
    ) internal pure {
        require(
            balance >= requiredAmount + freezeBalance,
            "Insufficient balance to cover the required amount and frozen balance."
        );
    }

    function requireRequestFinalized(bool isFinalized) internal pure {
        require(!isFinalized, "Request already finalized");
    }

    function requireTokenConsumed(
        uint256 tokenConsumed,
        uint256 tokenLimit
    ) internal pure {
        require(tokenConsumed <= tokenLimit, "Token limit exceeded");
    }

    function requireSufficientBalance(
        uint256 balance,
        uint256 tokenConsumed
    ) internal pure {
        require(
            balance >= tokenConsumed,
            "Requester has insufficient balance to cover the token consumption."
        );
    }

    function requireModel(
        string memory model,
        string[] memory allowedModels
    ) internal pure {
        bool isAllowedModel = false;
        for (uint i = 0; i < allowedModels.length; i++) {
            if (
                keccak256(abi.encodePacked(model)) ==
                keccak256(abi.encodePacked(allowedModels[i]))
            ) {
                isAllowedModel = true;
                break;
            }
        }
        require(isAllowedModel, "Model is not allowed.");
    }

    function requireRequestDataType(
        string memory model,
        string memory requestDataType,
        mapping(string => mapping(uint256 => string[])) storage allowedDataTypes
    ) internal view {
        bool isAllowedRequestDataType = false;
        string[] memory currentModelAllowedRequestDataType = allowedDataTypes[
            model
        ][0];
        for (uint i = 0; i < currentModelAllowedRequestDataType.length; i++) {
            if (
                keccak256(
                    abi.encodePacked(currentModelAllowedRequestDataType[i])
                ) == keccak256(abi.encodePacked(requestDataType))
            ) {
                isAllowedRequestDataType = true;
                break;
            }
        }
        require(isAllowedRequestDataType, "Request data type not allowed");
    }

    function requireResponseDataType(
        string memory model,
        string memory responseDataType,
        mapping(string => mapping(uint256 => string[])) storage allowedDataTypes
    ) internal view {
        bool isAllowedResponseDataType = false;
        string[] memory currentModelAllowedResponseDataType = allowedDataTypes[
            model
        ][1];
        for (uint i = 0; i < currentModelAllowedResponseDataType.length; i++) {
            if (
                keccak256(
                    abi.encodePacked(currentModelAllowedResponseDataType[i])
                ) == keccak256(abi.encodePacked(responseDataType))
            ) {
                isAllowedResponseDataType = true;
                break;
            }
        }
        require(isAllowedResponseDataType, "Response data type not allowed");
    }

    function requireOperationType(uint256 operationType) internal pure {
        require(
            operationType == 0 || operationType == 1,
            "Invalid operation type"
        );
    }

    function requireSegmentRange(
        uint256 segmentIndex,
        uint256 segmentCount,
        uint256 requestSegmentCount
    ) internal pure {
        require(
            segmentIndex + segmentCount <= requestSegmentCount,
            "Out of range"
        );
    }

    function requireSufficientWithdrawBalance(
        uint256 balance,
        uint256 freezeBalance,
        uint256 amount
    ) internal pure {
        require(balance - freezeBalance >= amount, "Insufficient balance");
    }

    function requireTransfer(bool success) internal pure {
        require(success, "Transfer failed");
    }
}
