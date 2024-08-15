// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import "../interfaces/IAIOracle.sol";

library AIOracleUtilsLib {
    function updateRequest(
        IAIOracle.Request storage request,
        uint256 tokenConsumed,
        bool isFinalSegment,
        uint256 additionalSegments
    ) internal {
        request.tokenConsumed += tokenConsumed;
        request.segmentCount += additionalSegments;
        if (isFinalSegment) {
            request.isFinalized = true;
        }
    }

    function pushSegments(
        bytes32[] storage segments,
        bytes32[] calldata newSegments
    ) internal {
        for (uint256 i = 0; i < newSegments.length; i++) {
            segments.push(newSegments[i]);
        }
    }

    function updateBalances(
        mapping(address => uint256) storage balances,
        mapping(address => uint256) storage freezeBalances,
        address user,
        uint256 tokenConsumed,
        uint256 tokenFreezed
    ) internal {
        balances[user] -= tokenConsumed;
        freezeBalances[user] -= tokenFreezed;
    }

    function updateAllowedDataTypes(
        mapping(string => mapping(uint256 => string[]))
            storage allowedDataTypes,
        string calldata model,
        string[] calldata newAllowedDataTypes,
        uint256 op
    ) internal {
        string[] storage curAllowedDataTypes = allowedDataTypes[model][op];
        uint i = 0;
        while (
            i < curAllowedDataTypes.length && i < newAllowedDataTypes.length
        ) {
            curAllowedDataTypes[i] = newAllowedDataTypes[i];
            i++;
        }

        while (i < curAllowedDataTypes.length) {
            curAllowedDataTypes.pop();
        }

        while (i < newAllowedDataTypes.length) {
            curAllowedDataTypes.push(newAllowedDataTypes[i]);
            i++;
        }
    }

    function setAllowedModels(
        string[] storage allowedModels,
        string[] calldata newAllowedModels
    ) internal {
        uint i = 0;
        while (i < allowedModels.length && i < newAllowedModels.length) {
            allowedModels[i] = newAllowedModels[i];
            i++;
        }

        while (i < allowedModels.length) {
            allowedModels.pop();
            i++;
        }

        while (i < newAllowedModels.length) {
            allowedModels.push(newAllowedModels[i]);
            i++;
        }
    }
}
