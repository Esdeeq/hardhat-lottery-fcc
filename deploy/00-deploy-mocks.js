const { network, ethers } = require("hardhat");
const { developmentChains } = require("../helper_hardhat");

//Cost per request
const BASE_FEE = ethers.utils.parseEther("0.05");
const GAS_PRICE_LINK = 1e9;
const args = [BASE_FEE, GAS_PRICE_LINK];

module.exports = async function ({ getNamedAccounts, deployments }) {
    const { deploy, log } = deployments;
    const { deployer } = await getNamedAccounts();
    const chainId = network.config.chainId;

    if (developmentChains.includes(network.name)) {
        log("Local network detected, deploying...");
        await deploy("VRFCoordinatorV2Mock", {
            from: deployer,
            log: true,
            args: args,
        });
        log("MocksDeployed!");
        log("-----------------------------------------------");
    }
};

module.exports.tags = ["all", "mocks"];
