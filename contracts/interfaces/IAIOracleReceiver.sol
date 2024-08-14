// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

interface IAIOracleReceiver {
    function onAIResponseReceive(uint256 requestId, bytes32[] calldata responseSegements, bool isFinalSegement) external;
}
