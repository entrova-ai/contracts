// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import "./interfaces/IAIOracle.sol";
import "./interfaces/IAIOracleReceiver.sol";
import "./libraries/AIOracleUtilsLib.sol";
import "./libraries/AIOracleValidationLib.sol";
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
    using AIOracleValidationLib for uint256;
    using AIOracleValidationLib for string;
    using AIOracleValidationLib for string[];
    using AIOracleValidationLib for mapping(string => mapping(uint256 => string[]));
    using AIOracleValidationLib for bool;

    using AIOracleUtilsLib for mapping(uint256 => IAIOracle.Request);
    using AIOracleUtilsLib for IAIOracle.Request;
    using AIOracleUtilsLib for bytes32[];
    using AIOracleUtilsLib for mapping(string => mapping(uint256 => string[]));
    using AIOracleUtilsLib for string[];
    using AIOracleUtilsLib for mapping(address => uint256);

    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant RESPONSE_ROLE = keccak256("RESPONSE_ROLE");
    uint256 public constant TOKEN_PER_SEGMENT = 1; // 1 AIToken per segment

    address public aiToken;
    uint256 public minTokenLimit;
    uint256 public requestCounter;

    string[] private allowedModels;

    mapping(uint256 => IAIOracle.Request) public requests;
    mapping(uint256 => bytes32[]) public responseSegments;
    mapping(address => uint256) private balances;
    mapping(address => uint256) private freezeBalances;
    mapping(string => mapping(uint256 => string[])) private allowedDataTypes;

    function initialize(
        address _aiToken,
        string[] calldata _allowedModels,
        string[][][] calldata _allowedDataTypes // model => operation type => data types
    ) public initializer {
        __AccessControl_init();

        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());

        aiToken = _aiToken;
        minTokenLimit = 5;
        require(_allowedDataTypes.length == _allowedModels.length);

        allowedModels.setAllowedModels(_allowedModels);

        for (uint i = 0; i < _allowedModels.length; i++) {
            string calldata model = _allowedModels[i];
            allowedDataTypes.updateAllowedDataTypes(
                model,
                _allowedDataTypes[i][0],
                0
            );
            allowedDataTypes.updateAllowedDataTypes(
                model,
                _allowedDataTypes[i][1],
                1
            );
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
        tokenLimit.requireTokenLimit(minTokenLimit);
        balances[msg.sender].requireBalance(
            tokenLimit,
            freezeBalances[msg.sender]
        );

        model.requireModel(allowedModels);
        model.requireRequestDataType(requestDataType, allowedDataTypes);
        model.requireResponseDataType(responseDataType, allowedDataTypes);

        freezeBalances[msg.sender] += tokenLimit;

        requestId = ++requestCounter;

        requests[requestId] = IAIOracle.Request({
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
        IAIOracle.Request storage request = requests[requestId];
        request.isFinalized.requireRequestFinalized();
        uint256 allTokenConsumed = request.tokenConsumed + tokenConsumed;
        allTokenConsumed.requireTokenConsumed(request.tokenLimit);
        balances[request.requester].requireSufficientBalance(tokenConsumed);

        responseSegments[requestId].pushSegments(resultSegments);

        request.updateRequest(
            tokenConsumed,
            isFinalSegment,
            resultSegments.length
        );

        emit AIResponseReceived(
            requestId,
            resultSegments,
            isFinalSegment,
            tokenConsumed
        );

        ERC20Burnable(aiToken).burn(tokenConsumed);
        balances.updateBalances(
            freezeBalances,
            request.requester,
            tokenConsumed,
            request.tokenFreezed
        );
        request.tokenFreezed = 0;

        address receiver = request.receiver;
        if (receiver == address(0)) {
            return;
        }
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
        IAIOracle.Request storage request = requests[requestId];

        request.isFinalized.requireRequestFinalized();
        balances[msg.sender].requireBalance(
            additionalTokenLimit,
            freezeBalances[msg.sender]
        );

        freezeBalances[msg.sender] += additionalTokenLimit;

        request.tokenFreezed += additionalTokenLimit;
        request.tokenLimit += additionalTokenLimit;

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
        IAIOracle.Request storage request = requests[requestId];
        AIOracleValidationLib.requireSegmentRange(
            segmentIndex,
            segmentCount,
            request.segmentCount
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
        AIOracleValidationLib.requireOperationType(operationType);
        return allowedDataTypes[model][operationType];
    }

    function depositTokens(uint256 amount) external override {
        AIOracleValidationLib.requireTransfer(
            IERC20(aiToken).transferFrom(msg.sender, address(this), amount)
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
        balances[msg.sender].requireSufficientWithdrawBalance(
            freezeBalances[msg.sender],
            amount
        );
        uint256 oldBalance = balances[msg.sender];
        balances[msg.sender] -= amount;
        AIOracleValidationLib.requireTransfer(
            IERC20(aiToken).transfer(msg.sender, amount)
        );

        emit BalanceUpdated(msg.sender, oldBalance, balances[msg.sender]);
    }

    function withdrawTokenTo(uint256 amount, address to) external override {
        balances[msg.sender].requireSufficientWithdrawBalance(
            freezeBalances[msg.sender],
            amount
        );
        uint256 oldBalance = balances[msg.sender];
        balances[msg.sender] -= amount;
        AIOracleValidationLib.requireTransfer(
            IERC20(aiToken).transfer(to, amount)
        );

        emit BalanceUpdated(msg.sender, oldBalance, balances[msg.sender]);
    }

    function setAllowedModels(
        string[] calldata newAllowedModels
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        allowedModels.setAllowedModels(newAllowedModels);
    }

    function setAllowedDataTypes(
        string calldata model,
        uint256 op, // operation
        string[] calldata newAllowedDataTypes
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        allowedDataTypes.updateAllowedDataTypes(model, newAllowedDataTypes, op);
    }

    function setMinTokenLimit(
        uint256 newTokenLimit
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        minTokenLimit = newTokenLimit;
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(UPGRADER_ROLE) {}
}
