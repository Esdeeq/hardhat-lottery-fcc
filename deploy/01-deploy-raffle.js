const { network, ethers } = require("hardhat");
const { developmentChains, networkConfig } = require("../helper_hardhat");
const { verify } = require("../helper_hardhat");

const SUB_AMOUNT = ethers.utils.parseEther("30");

module.exports = async function ({ getNamedAccounts, deployments }) {
    const { deploy, log } = deployments;
    const { deployer } = await getNamedAccounts();
    const chainId = network.config.chainId;

    let vrfCoordinatorV2Address, subscriptionId;

    if (developmentChains.includes(network.name)) {
        const vrfCoordinatorV2Mock = await ethers.getContract("VRFCoordinatorV2Mock");
        vrfCoordinatorV2Address = vrfCoordinatorV2Mock.target;
        const transactionResponse = await vrfCoordinatorV2Mock.createSubscription();
        const transactionReceipt = await transactionResponse.wait(1);
        // subscriptionId = transactionReceipt.logs[0].args.subId;

        await vrfCoordinatorV2Mock.fundSubscription(subscriptionId, SUB_AMOUNT);
    } else {
        vrfCoordinatorV2Address = networkConfig[chainId]["vrfCoordinatorV2"];
        subscriptionId = networkConfig[chainId]["subscriptionId"];
    }

    const entranceFee = networkConfig[chainId]["entranceFee"];
    const keyHash = networkConfig[chainId]["keyHash"];
    const callBackGasLimit = networkConfig[chainId]["callBackGasLimit"];
    const interval = networkConfig[chainId]["interval"];

    const args = [
        vrfCoordinatorV2Address,
        entranceFee,
        keyHash,
        subscriptionId,
        callBackGasLimit,
        interval,
    ];
    const raffle = await deploy("Raffle", {
        from: deployer,
        args: args,
        log: true,
        waitConfirmations: network.config.blockConfirmations,
    });
    if (!developmentChains.includes(network.name) && process.env.ETHERSCAN_API) {
        log("Verifying...");
        await verify(raffle.address, args);
    }
    log("------------------------------------------------");
};

module.exports.tags = ["all", "raffle"];
