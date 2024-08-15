// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import "./interfaces/IAIOracle.sol";
import "./interfaces/IAIOracleReceiver.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract AIOracle is
    IAIOracle,
    Initializable,
    AccessControlUpgradeable,
    UUPSUpgradeable
{
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant RESPONSE_ROLE = keccak256("RESPONSE_ROLE");
    uint256 public constant TOKEN_PER_SEGMENT = 1; // 1 AIToken per segment

    struct Request {
        address requester;
        address receiver;
        string model;
        string requestDataType;
        string responseDataType;
        uint256 tokenLimit;
        uint256 tokenConsumed;
        bytes data;
        bool isFinalized;
        uint256 segmentCount;
        uint256 tokenFreezed;
    }

    address public aiToken;
    uint256 public minTokenLimit;
    uint256 public requestCounter;

    string[] private allowedModels;

    mapping(uint256 => Request) public requests;
    mapping(uint256 => bytes32[]) public responseSegments;
    mapping(address => uint256) private balances;
    mapping(address => uint256) private freezeBalances;
    mapping(string => mapping(uint256 => string[])) private allowedDataTypes;

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _aiToken,
        string[] calldata _allowedModels,
        string[][][] calldata _allowedDataTypes // model => operation type => data types
    ) public initializer {
        __AccessControl_init();

        aiToken = _aiToken;
        minTokenLimit = 5;
        require(_allowedDataTypes.length == _allowedModels.length);
        for (uint i = 0; i < allowedModels.length; i++) {
            allowedModels[i] = _allowedModels[i];
        }

        for (uint i = 0; i < _allowedModels.length; i++) {
            string calldata model = _allowedModels[i];
            _setAllowedDataTypes(model, _allowedDataTypes[i][0], 0);
            _setAllowedDataTypes(model, _allowedDataTypes[i][1], 1);
        }
    }

    function createAIRequest(
        bytes calldata data,
        string memory model,
        string memory requestDataType,
        string memory responseDataType,
        uint256 previousRequestId,
        address receiver,
        uint256 tokenLimit
    ) external override returns (uint256 requestId) {
        require(
            tokenLimit >= minTokenLimit,
            "Token limit is below the minimum required."
        );
        require(
            balances[msg.sender] >= tokenLimit + freezeBalances[msg.sender],
            "Insufficient balance to cover the token limit and frozen balance."
        );

        _verifyModel(model);
        _verifyRequestDataType(model, requestDataType);
        _verifyResponseDataType(model, responseDataType);

        freezeBalances[msg.sender] += tokenLimit;

        requestId = ++requestCounter;

        requests[requestId] = Request({
            requester: msg.sender,
            receiver: receiver,
            model: model,
            requestDataType: requestDataType,
            responseDataType: responseDataType,
            tokenLimit: tokenLimit,
            tokenConsumed: 0,
            data: data,
            isFinalized: false,
            segmentCount: 0,
            tokenFreezed: tokenLimit
        });

        emit AIRequestCreated(
            requestId,
            msg.sender,
            receiver,
            data,
            model,
            requestDataType,
            responseDataType,
            previousRequestId,
            tokenLimit
        );
    }

    function submitAIResponseSegments(
        uint256 requestId,
        bytes32[] calldata resultSegments,
        bool isFinalSegment,
        uint256 tokenConsumed,
        uint256 gasLimit
    ) external override onlyRole(RESPONSE_ROLE) {
        Request memory request = requests[requestId];
        require(!request.isFinalized, "Request already finalized");
        require(
            request.tokenConsumed + tokenConsumed <= request.tokenLimit,
            "Token limit exceeded"
        );
        require(
            balances[request.requester] >= tokenConsumed,
            "Requester has insufficient balance to cover the token consumption."
        );

        bytes32[] storage curResponseSegements = responseSegments[requestId];
        for (uint256 i = 0; i < resultSegments.length; i++) {
            curResponseSegements.push(resultSegments[i]);
        }

        request.tokenConsumed += tokenConsumed;
        request.segmentCount += resultSegments.length;

        if (isFinalSegment) {
            request.isFinalized = true;
        }

        emit AIResponseReceived(
            requestId,
            resultSegments,
            isFinalSegment,
            tokenConsumed
        );

        ERC20Burnable(aiToken).burn(tokenConsumed);
        balances[msg.sender] -= tokenConsumed;
        freezeBalances[msg.sender] -= request.tokenFreezed;
        request.tokenFreezed = 0;

        requests[requestId] = request;

        address receiver = request.receiver;
        IAIOracleReceiver(receiver).onAIResponseReceive{gas: gasLimit}(
            requestId,
            resultSegments,
            isFinalSegment
        );
    }

    function continueAIResponse(
        uint256 requestId,
        uint256 additionalTokenLimit
    ) external override {
        Request memory request = requests[requestId];

        require(!request.isFinalized, "Request already finalized");
        require(
            balances[msg.sender] - freezeBalances[msg.sender] >=
                additionalTokenLimit,
            "Token limit exceeded"
        );

        freezeBalances[msg.sender] += additionalTokenLimit;

        request.tokenFreezed += additionalTokenLimit;
        request.tokenLimit += additionalTokenLimit;
        requests[requestId] = request;

        emit ContinueAIResponse(
            requestId,
            additionalTokenLimit,
            request.tokenLimit
        );
    }

    function getAIResponseSegments(
        uint256 requestId,
        uint256 segmentIndex,
        uint256 segmentCount
    )
        external
        view
        override
        returns (bytes32[] memory resultSegments, bool isFinalSegment)
    {
        Request storage request = requests[requestId];
        require(
            segmentIndex + segmentCount <= request.segmentCount,
            "Out of range"
        );

        resultSegments = new bytes32[](segmentCount);
        for (uint256 i = 0; i < segmentCount; i++) {
            resultSegments[i] = responseSegments[requestId][segmentIndex + i];
        }

        isFinalSegment =
            request.isFinalized &&
            (segmentIndex + segmentCount == request.segmentCount);
    }

    function getAIResponseSegmentCount(
        uint256 requestId
    ) external view override returns (uint256 segmentCount) {
        return requests[requestId].segmentCount;
    }

    function getAllowedModels()
        external
        view
        override
        returns (string[] memory models)
    {
        return allowedModels;
    }

    function getAllowedDataTypes(
        string calldata model,
        uint256 operationType
    ) external view override returns (string[] memory dataTypes) {
        require(
            operationType == 0 || operationType == 1,
            "Invalid operation type"
        );
        return allowedDataTypes[model][operationType];
    }

    function depositTokens(uint256 amount) external override {
        require(
            IERC20(aiToken).transferFrom(msg.sender, address(this), amount),
            "Transfer failed"
        );
        uint256 oldBalance = balances[msg.sender];
        balances[msg.sender] += amount;

        emit BalanceUpdated(msg.sender, oldBalance, balances[msg.sender]);
    }

    function getTokenBalance(
        address user
    ) external view override returns (uint256 balance) {
        return balances[user];
    }

    function withdrawToken(uint256 amount) external override {
        require(
            balances[msg.sender] - freezeBalances[msg.sender] >= amount,
            "Insufficient balance"
        );
        uint256 oldBalance = balances[msg.sender];
        balances[msg.sender] -= amount;
        require(
            IERC20(aiToken).transfer(msg.sender, amount),
            "Transfer failed"
        );

        emit BalanceUpdated(msg.sender, oldBalance, balances[msg.sender]);
    }

    function withdrawTokenTo(uint256 amount, address to) external override {
        require(
            balances[msg.sender] - freezeBalances[msg.sender] >= amount,
            "Insufficient balance"
        );
        uint256 oldBalance = balances[msg.sender];
        balances[msg.sender] -= amount;
        require(IERC20(aiToken).transfer(to, amount), "Transfer failed");

        emit BalanceUpdated(msg.sender, oldBalance, balances[msg.sender]);
    }

    function setAllowedModels(
        string[] calldata newAllowedModels
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        for (uint i = 0; i < newAllowedModels.length; i++) {
            allowedModels[i] = newAllowedModels[i];
        }
        while (allowedModels.length > newAllowedModels.length) {
            allowedModels.pop();
        }
    }

    function setAllowedDataTypes(
        string calldata model,
        uint256 op, // operation
        string[] calldata newAllowedDataTypes
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        string[] storage curAllowedDataTypes = allowedDataTypes[model][op];
        while (curAllowedDataTypes.length > newAllowedDataTypes.length) {
            curAllowedDataTypes.pop();
        }
        _setAllowedDataTypes(model, newAllowedDataTypes, op);
    }

    function setMinTokenLimit(
        uint256 newTokenLimit
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        minTokenLimit = newTokenLimit;
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(UPGRADER_ROLE) {}

    function _verifyModel(string memory model) internal view {
        bool isAllowedModel = false;
        for (uint i = 0; i < allowedModels.length; i++) {
            string memory currentModel = allowedModels[i];
            if (
                keccak256(abi.encodePacked(model)) ==
                keccak256(abi.encodePacked(currentModel))
            ) {
                isAllowedModel = true;
                break;
            }
        }
        require(isAllowedModel, "Model is not allowed.");
    }

    function _verifyRequestDataType(
        string memory model,
        string memory requestDataType
    ) internal view {
        bool isAllowedRequestDataType = false;
        string[] memory currentModelAllowedRequestDataType = allowedDataTypes[
            model
        ][0];
        for (uint i = 0; i < currentModelAllowedRequestDataType.length; i++) {
            string memory currentDataTypes = currentModelAllowedRequestDataType[
                i
            ];
            if (
                keccak256(abi.encodePacked(currentDataTypes)) ==
                keccak256(abi.encodePacked(requestDataType))
            ) {
                isAllowedRequestDataType = true;
                break;
            }
        }
        require(isAllowedRequestDataType, "Request data type not allowed");
    }

    function _verifyResponseDataType(
        string memory model,
        string memory requestDataType
    ) internal view {
        bool isAllowedResponseDataType = false;
        string[] memory currentModelAllowedResponseDataType = allowedDataTypes[
            model
        ][1];
        for (uint i = 0; i < currentModelAllowedResponseDataType.length; i++) {
            string
                memory currentDataTypes = currentModelAllowedResponseDataType[
                    i
                ];
            if (
                keccak256(abi.encodePacked(currentDataTypes)) ==
                keccak256(abi.encodePacked(requestDataType))
            ) {
                isAllowedResponseDataType = true;
                break;
            }
        }
        require(isAllowedResponseDataType, "Response data type not allowed");
    }

    function _setAllowedDataTypes(
        string calldata model,
        string[] calldata newAllowedDataTypes,
        uint256 op
    ) internal {
        string[] storage curAllowedDataTypes = allowedDataTypes[model][op];
        for (uint j = 0; j < newAllowedDataTypes.length; j++) {
            curAllowedDataTypes[j] = newAllowedDataTypes[j];
        }
    }
}
