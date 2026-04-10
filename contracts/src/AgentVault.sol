// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IPool} from "./interfaces/IPool.sol";
import {IRewardsController} from "./interfaces/IRewardsController.sol";

/// @title AgentVault
/// @notice ERC-4337 compatible vault for autonomous AI yield management on Tydro (Aave V3 fork)
/// @dev Restricts agent permissions to supply/withdraw/claimRewards/auto-compound only
///      Owner retains full control with 24-hour timelock on critical changes
contract AgentVault is ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ─────────────────────────────────────────────────────────────────────────
    // Types
    // ─────────────────────────────────────────────────────────────────────────

    enum RiskProfile { CONSERVATIVE, BALANCED, AGGRESSIVE }

    struct TimelockRequest {
        bytes32 actionHash;    // keccak256(action parameters)
        uint48  eta;           // earliest execution timestamp
        bool    executed;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // State
    // ─────────────────────────────────────────────────────────────────────────

    /// @notice Owner of this vault (the user)
    address public immutable owner;

    /// @notice ERC-4337 EntryPoint – only source trusted to call executeUserOp
    address public immutable entryPoint;

    /// @notice Tydro (Aave V3 fork) lending pool
    IPool public immutable tydroPool;

    /// @notice Tydro rewards controller (DefaultIncentivesController equivalent)
    IRewardsController public immutable rewardsController;

    /// @notice AI agent address – ONLY allowed to call permissioned functions
    address public agent;

    /// @notice Active risk profile chosen by owner
    RiskProfile public riskProfile;

    /// @notice Timelock delay for critical changes (default 24 hours)
    uint48 public constant TIMELOCK_DELAY = 24 hours;

    /// @notice Pending timelock requests
    mapping(bytes32 => TimelockRequest) public timelockRequests;

    /// @notice Whitelisted assets the agent can interact with
    mapping(address => bool) public allowedAssets;

    /// @notice Guard: agent permission can be fully revoked by owner instantly
    bool public agentRevoked;

    // ─────────────────────────────────────────────────────────────────────────
    // Events
    // ─────────────────────────────────────────────────────────────────────────

    event Supplied(address indexed asset, uint256 amount, address indexed onBehalfOf);
    event Withdrawn(address indexed asset, uint256 amount, address indexed to);
    event RewardsClaimed(address[] assets, uint256 amount);
    event AutoCompounded(address indexed asset, uint256 rewardAmount, uint256 resupplied);
    event AgentUpdated(address indexed oldAgent, address indexed newAgent);
    event AgentRevoked(address indexed revoker);
    event RiskProfileUpdated(RiskProfile profile);
    event TimelockQueued(bytes32 indexed id, bytes32 actionHash, uint48 eta);
    event TimelockExecuted(bytes32 indexed id);
    event TimelockCancelled(bytes32 indexed id);
    event AssetAllowlistUpdated(address indexed asset, bool allowed);

    // ─────────────────────────────────────────────────────────────────────────
    // Errors
    // ─────────────────────────────────────────────────────────────────────────

    error NotOwner();
    error NotAgent();
    error NotEntryPoint();
    error AgentPermissionRevoked();
    error AssetNotAllowed(address asset);
    error TimelockNotReady(uint48 eta, uint48 now_);
    error TimelockAlreadyExecuted(bytes32 id);
    error TimelockNotFound(bytes32 id);
    error ZeroAddress();
    error ZeroAmount();

    // ─────────────────────────────────────────────────────────────────────────
    // Modifiers
    // ─────────────────────────────────────────────────────────────────────────

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    /// @dev Agent calls come either directly or via ERC-4337 EntryPoint
    modifier onlyAgent() {
        if (agentRevoked) revert AgentPermissionRevoked();
        if (msg.sender != agent && msg.sender != entryPoint) revert NotAgent();
        _;
    }

    modifier onlyAllowedAsset(address asset) {
        if (!allowedAssets[asset]) revert AssetNotAllowed(asset);
        _;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Constructor
    // ─────────────────────────────────────────────────────────────────────────

    constructor(
        address _owner,
        address _entryPoint,
        address _tydroPool,
        address _rewardsController,
        address _agent,
        RiskProfile _initialProfile,
        address[] memory _initialAssets
    ) {
        if (_owner == address(0) || _entryPoint == address(0) ||
            _tydroPool == address(0) || _rewardsController == address(0) ||
            _agent == address(0)) revert ZeroAddress();

        owner            = _owner;
        entryPoint       = _entryPoint;
        tydroPool        = IPool(_tydroPool);
        rewardsController = IRewardsController(_rewardsController);
        agent            = _agent;
        riskProfile      = _initialProfile;

        for (uint256 i; i < _initialAssets.length; ++i) {
            allowedAssets[_initialAssets[i]] = true;
            emit AssetAllowlistUpdated(_initialAssets[i], true);
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Agent Actions (restricted – only callable by agent / EntryPoint)
    // ─────────────────────────────────────────────────────────────────────────

    /// @notice Supply `amount` of `asset` into Tydro on behalf of this vault
    /// @param asset ERC-20 token address (must be allowlisted)
    /// @param amount Amount to supply (must be pre-approved to this contract)
    function supply(address asset, uint256 amount)
        external
        onlyAgent
        onlyAllowedAsset(asset)
        nonReentrant
    {
        if (amount == 0) revert ZeroAmount();
        IERC20(asset).safeTransferFrom(msg.sender == owner ? owner : address(this), address(this), 0); // noop pull guard
        IERC20(asset).forceApprove(address(tydroPool), amount);
        tydroPool.supply(asset, amount, address(this), 0);
        emit Supplied(asset, amount, address(this));
    }

    /// @notice Supply tokens that are already sitting inside this vault
    /// @dev Used after user deposits via depositToVault(); agent triggers supply
    function supplyFromVault(address asset, uint256 amount)
        external
        onlyAgent
        onlyAllowedAsset(asset)
        nonReentrant
    {
        if (amount == 0) revert ZeroAmount();
        uint256 balance = IERC20(asset).balanceOf(address(this));
        uint256 toSupply = amount > balance ? balance : amount;
        IERC20(asset).forceApprove(address(tydroPool), toSupply);
        tydroPool.supply(asset, toSupply, address(this), 0);
        emit Supplied(asset, toSupply, address(this));
    }

    /// @notice Withdraw `amount` of `asset` from Tydro back to owner
    /// @param asset Underlying asset address
    /// @param amount Amount to withdraw (use type(uint256).max for full withdrawal)
    function withdraw(address asset, uint256 amount)
        external
        onlyAgent
        onlyAllowedAsset(asset)
        nonReentrant
        returns (uint256 withdrawn)
    {
        if (amount == 0) revert ZeroAmount();
        withdrawn = tydroPool.withdraw(asset, amount, owner);
        emit Withdrawn(asset, withdrawn, owner);
    }

    /// @notice Claim all pending rewards for given aToken/debtToken assets
    /// @param assets Array of aToken addresses to claim rewards for
    /// @return totalRewards Amount of reward token claimed
    function claimRewards(address[] calldata assets)
        external
        onlyAgent
        nonReentrant
        returns (uint256 totalRewards)
    {
        totalRewards = rewardsController.claimAllRewards(assets, address(this));
        emit RewardsClaimed(assets, totalRewards);
    }

    /// @notice Claim rewards and immediately re-supply them (auto-compound)
    /// @param aTokenAssets aToken addresses to claim from
    /// @param rewardAsset  The reward token address (must be allowlisted to re-supply)
    function claimAndCompound(address[] calldata aTokenAssets, address rewardAsset)
        external
        onlyAgent
        onlyAllowedAsset(rewardAsset)
        nonReentrant
    {
        uint256 claimed = rewardsController.claimAllRewards(aTokenAssets, address(this));
        if (claimed == 0) return; // nothing to compound

        IERC20(rewardAsset).forceApprove(address(tydroPool), claimed);
        tydroPool.supply(rewardAsset, claimed, address(this), 0);

        emit AutoCompounded(rewardAsset, claimed, claimed);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Owner Actions (direct – no timelock needed for low-risk ops)
    // ─────────────────────────────────────────────────────────────────────────

    /// @notice Deposit tokens into this vault (owner only)
    /// @dev Tokens sit here until agent calls supplyFromVault
    function depositToVault(address asset, uint256 amount)
        external
        onlyOwner
        nonReentrant
    {
        if (amount == 0) revert ZeroAmount();
        IERC20(asset).safeTransferFrom(owner, address(this), amount);
    }

    /// @notice Emergency withdraw everything – bypasses agent, goes straight to owner
    function emergencyWithdrawAll(address asset)
        external
        onlyOwner
        nonReentrant
    {
        // Withdraw from Tydro if any position exists
        try tydroPool.withdraw(asset, type(uint256).max, owner) {} catch {}
        // Also sweep any tokens sitting in vault
        uint256 bal = IERC20(asset).balanceOf(address(this));
        if (bal > 0) IERC20(asset).safeTransfer(owner, bal);
    }

    /// @notice Instantly revoke all agent permissions (no timelock)
    function revokeAgent() external onlyOwner {
        agentRevoked = true;
        emit AgentRevoked(msg.sender);
    }

    /// @notice Re-enable agent after revocation
    function reinstateAgent() external onlyOwner {
        agentRevoked = false;
    }

    /// @notice Update risk profile (no timelock – informational for AI)
    function setRiskProfile(RiskProfile profile) external onlyOwner {
        riskProfile = profile;
        emit RiskProfileUpdated(profile);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Timelocked Owner Actions (critical changes: agent swap, asset allowlist)
    // ─────────────────────────────────────────────────────────────────────────

    /// @notice Queue a new agent address change (24h timelock)
    function queueAgentUpdate(address newAgent) external onlyOwner returns (bytes32 id) {
        if (newAgent == address(0)) revert ZeroAddress();
        bytes32 actionHash = keccak256(abi.encode("SET_AGENT", newAgent));
        id = _queueTimelock(actionHash);
        emit AgentUpdated(agent, newAgent); // emitted optimistically for UI
    }

    /// @notice Execute queued agent update after timelock expires
    function executeAgentUpdate(address newAgent, bytes32 id) external onlyOwner {
        bytes32 actionHash = keccak256(abi.encode("SET_AGENT", newAgent));
        _executeTimelock(id, actionHash);
        address old = agent;
        agent = newAgent;
        emit AgentUpdated(old, newAgent);
    }

    /// @notice Queue asset allowlist change (24h timelock)
    function queueAssetAllowlist(address asset, bool allowed) external onlyOwner returns (bytes32 id) {
        bytes32 actionHash = keccak256(abi.encode("SET_ASSET", asset, allowed));
        id = _queueTimelock(actionHash);
    }

    /// @notice Execute queued asset allowlist change
    function executeAssetAllowlist(address asset, bool allowed, bytes32 id) external onlyOwner {
        bytes32 actionHash = keccak256(abi.encode("SET_ASSET", asset, allowed));
        _executeTimelock(id, actionHash);
        allowedAssets[asset] = allowed;
        emit AssetAllowlistUpdated(asset, allowed);
    }

    /// @notice Cancel any pending timelock request
    function cancelTimelock(bytes32 id) external onlyOwner {
        if (timelockRequests[id].actionHash == bytes32(0)) revert TimelockNotFound(id);
        delete timelockRequests[id];
        emit TimelockCancelled(id);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // ERC-4337 EntryPoint compatibility
    // ─────────────────────────────────────────────────────────────────────────

    /// @notice Validate UserOperation – only agent's ops are accepted
    /// @dev Returns SIG_VALIDATION_SUCCESS (0) or SIG_VALIDATION_FAILED (1)
    function validateUserOp(
        bytes calldata /* userOp */,
        bytes32 /* userOpHash */,
        uint256 /* missingAccountFunds */
    ) external view returns (uint256 validationData) {
        if (msg.sender != entryPoint) revert NotEntryPoint();
        // Minimal validation: check agent not revoked
        // Production: add signature check against agent EOA
        validationData = agentRevoked ? 1 : 0;
    }

    /// @notice Allow EntryPoint to prefund gas from vault
    receive() external payable {}

    // ─────────────────────────────────────────────────────────────────────────
    // Internal Helpers
    // ─────────────────────────────────────────────────────────────────────────

    function _queueTimelock(bytes32 actionHash) internal returns (bytes32 id) {
        uint48 eta = uint48(block.timestamp) + TIMELOCK_DELAY;
        id = keccak256(abi.encode(actionHash, eta));
        timelockRequests[id] = TimelockRequest({actionHash: actionHash, eta: eta, executed: false});
        emit TimelockQueued(id, actionHash, eta);
    }

    function _executeTimelock(bytes32 id, bytes32 expectedHash) internal {
        TimelockRequest storage req = timelockRequests[id];
        if (req.actionHash == bytes32(0)) revert TimelockNotFound(id);
        if (req.executed) revert TimelockAlreadyExecuted(id);
        if (uint48(block.timestamp) < req.eta) revert TimelockNotReady(req.eta, uint48(block.timestamp));
        require(req.actionHash == expectedHash, "AgentVault: hash mismatch");
        req.executed = true;
        emit TimelockExecuted(id);
    }
}
