// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {AgentVault} from "../src/AgentVault.sol";

contract DeployAgentVault is Script {
    function run() external {
        address owner             = vm.envAddress("VAULT_OWNER");
        address entryPoint        = vm.envAddress("ENTRY_POINT");
        address tydroPool         = vm.envAddress("TYDRO_POOL");
        address rewardsController = vm.envAddress("TYDRO_REWARDS");
        address agent             = vm.envAddress("AGENT_ADDRESS");
        uint8   profile           = uint8(vm.envOr("RISK_PROFILE", uint256(1)));

        address[] memory assets = new address[](1);
        assets[0] = vm.envAddress("INITIAL_ASSETS");

        console2.log("Deploying AgentVault...");
        console2.log("  Owner:", owner);
        console2.log("  Agent:", agent);
        console2.log("  Pool: ", tydroPool);

        vm.startBroadcast();
        AgentVault vault = new AgentVault(
            owner, entryPoint, tydroPool,
            rewardsController, agent,
            AgentVault.RiskProfile(profile), assets
        );
        vm.stopBroadcast();

        console2.log("AgentVault deployed at:", address(vault));
    }
}
