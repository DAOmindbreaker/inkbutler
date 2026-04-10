// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test, console2} from "forge-std/Test.sol";
import {AgentVault} from "../src/AgentVault.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @dev Minimal mock for Tydro pool
contract MockPool {
    mapping(address => uint256) public supplied;
    function supply(address asset, uint256 amount, address, uint16) external {
        IERC20(asset).transferFrom(msg.sender, address(this), amount);
        supplied[asset] += amount;
    }
    function withdraw(address asset, uint256 amount, address to) external returns (uint256) {
        uint256 bal = supplied[asset];
        uint256 out = amount > bal ? bal : amount;
        supplied[asset] -= out;
        IERC20(asset).transfer(to, out);
        return out;
    }
    function getUserAccountData(address) external pure returns (uint256,uint256,uint256,uint256,uint256,uint256) {
        return (1000e8, 0, 500e8, 8000, 7500, type(uint256).max);
    }
}

/// @dev Minimal mock ERC-20
contract MockERC20 {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    string public name = "Mock USDC";
    string public symbol = "mUSDC";
    uint8  public decimals = 6;
    uint256 public totalSupply;

    function mint(address to, uint256 amount) external { balanceOf[to] += amount; totalSupply += amount; }
    function approve(address spender, uint256 amount) external returns (bool) { allowance[msg.sender][spender] = amount; return true; }
    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount; balanceOf[to] += amount; return true;
    }
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        allowance[from][msg.sender] -= amount; balanceOf[from] -= amount; balanceOf[to] += amount; return true;
    }
}

/// @dev Minimal rewards mock
contract MockRewards {
    function claimAllRewards(address[] calldata, address) external pure returns (uint256) { return 0; }
    function getUserRewards(address[] calldata, address, address) external pure returns (uint256) { return 0; }
    function getAllUserRewards(address[] calldata, address) external pure returns (address[] memory, uint256[] memory) {
        return (new address[](0), new uint256[](0));
    }
}

contract AgentVaultTest is Test {
    AgentVault vault;
    MockPool   pool;
    MockERC20  usdc;
    MockRewards rewards;

    address owner      = makeAddr("owner");
    address agent      = makeAddr("agent");
    address entryPoint = makeAddr("entryPoint");
    address attacker   = makeAddr("attacker");

    function setUp() public {
        pool    = new MockPool();
        usdc    = new MockERC20();
        rewards = new MockRewards();

        address[] memory assets = new address[](1);
        assets[0] = address(usdc);

        vault = new AgentVault(
            owner,
            entryPoint,
            address(pool),
            address(rewards),
            agent,
            AgentVault.RiskProfile.BALANCED,
            assets
        );

        // Fund owner
        usdc.mint(owner, 1_000_000e6);
    }

    // ── Ownership / Access ────────────────────────────────────────────────────

    function test_ownerIsSet() public view {
        assertEq(vault.owner(), owner);
    }

    function test_nonOwnerCannotRevokeAgent() public {
        vm.prank(attacker);
        vm.expectRevert(AgentVault.NotOwner.selector);
        vault.revokeAgent();
    }

    function test_ownerCanRevokeAgent() public {
        vm.prank(owner);
        vault.revokeAgent();
        assertTrue(vault.agentRevoked());
    }

    // ── Deposit & Supply ─────────────────────────────────────────────────────

    function test_ownerDepositsToVault() public {
        vm.startPrank(owner);
        usdc.approve(address(vault), 1000e6);
        vault.depositToVault(address(usdc), 1000e6);
        vm.stopPrank();

        assertEq(usdc.balanceOf(address(vault)), 1000e6);
    }

    function test_agentSuppliesFromVault() public {
        vm.startPrank(owner);
        usdc.approve(address(vault), 1000e6);
        vault.depositToVault(address(usdc), 1000e6);
        vm.stopPrank();

        vm.prank(agent);
        vault.supplyFromVault(address(usdc), 1000e6);

        assertEq(pool.supplied(address(usdc)), 1000e6);
        assertEq(usdc.balanceOf(address(vault)), 0);
    }

    function test_attackerCannotSupply() public {
        vm.prank(attacker);
        vm.expectRevert(AgentVault.NotAgent.selector);
        vault.supplyFromVault(address(usdc), 100e6);
    }

    function test_agentCannotUseRevokedPermission() public {
        vm.prank(owner);
        vault.revokeAgent();

        vm.prank(agent);
        vm.expectRevert(AgentVault.AgentPermissionRevoked.selector);
        vault.supplyFromVault(address(usdc), 100e6);
    }

    // ── Timelock ──────────────────────────────────────────────────────────────

    function test_timelockNotReadyReverts() public {
        address newAgent = makeAddr("newAgent");
        vm.prank(owner);
        bytes32 id = vault.queueAgentUpdate(newAgent);

        vm.prank(owner);
        vm.expectRevert(); // TimelockNotReady
        vault.executeAgentUpdate(newAgent, id);
    }

    function test_timelockExecutesAfterDelay() public {
        address newAgent = makeAddr("newAgent");
        vm.prank(owner);
        bytes32 id = vault.queueAgentUpdate(newAgent);

        vm.warp(block.timestamp + 24 hours + 1);

        vm.prank(owner);
        vault.executeAgentUpdate(newAgent, id);

        assertEq(vault.agent(), newAgent);
    }

    function test_timelockCanBeCancelled() public {
        address newAgent = makeAddr("newAgent");
        vm.prank(owner);
        bytes32 id = vault.queueAgentUpdate(newAgent);

        vm.prank(owner);
        vault.cancelTimelock(id);

        vm.warp(block.timestamp + 24 hours + 1);

        vm.prank(owner);
        vm.expectRevert(); // TimelockNotFound
        vault.executeAgentUpdate(newAgent, id);
    }

    // ── Risk Profile ──────────────────────────────────────────────────────────

    function test_ownerSetsRiskProfile() public {
        vm.prank(owner);
        vault.setRiskProfile(AgentVault.RiskProfile.AGGRESSIVE);
        assertEq(uint8(vault.riskProfile()), uint8(AgentVault.RiskProfile.AGGRESSIVE));
    }

    // ── Emergency Withdraw ────────────────────────────────────────────────────

    function test_emergencyWithdrawSweepsVault() public {
        usdc.mint(address(vault), 500e6);
        uint256 before = usdc.balanceOf(owner);

        vm.prank(owner);
        vault.emergencyWithdrawAll(address(usdc));

        assertEq(usdc.balanceOf(owner), before + 500e6);
    }
}
