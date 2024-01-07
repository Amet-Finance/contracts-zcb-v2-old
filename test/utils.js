const {ethers} = require("hardhat");

async function mineBlocks(provider, count = 1) {
    for (let i = 0; i < count; i++) {
        await provider.send("evm_mine");
    }
}

function issuerContractDefaultParams() {
    const initialFee = BigInt(1e18);
    const initialVaultPurchaseFeePercentage = BigInt(50);
    const initialEarlyRedemptionFeePercentage = BigInt(25);
    return {initialFee, initialVaultPurchaseFeePercentage, initialEarlyRedemptionFeePercentage}
}

async function deployIssuerContract(params) {
    const defaultParams = issuerContractDefaultParams()
    const initialFee = params?.initialFee || defaultParams.initialFee
    const initialVaultPurchaseFeePercentage = params?.initialVaultPurchaseFeePercentage || defaultParams.initialVaultPurchaseFeePercentage;
    const initialEarlyRedemptionFeePercentage = params?.initialEarlyRedemptionFeePercentage || defaultParams.initialEarlyRedemptionFeePercentage;
    return await ethers.deployContract("ZeroCouponBondsIssuer", [initialFee, initialVaultPurchaseFeePercentage, initialEarlyRedemptionFeePercentage]);
}

async function deployVaultContract(issuerContract) {
    return await ethers.deployContract("AmetVault", [issuerContract]);
}

async function deployTokenContract() {
    return await ethers.deployContract("Token", []);
}

module.exports = {
    issuerContractDefaultParams,
    deployIssuerContract,
    deployVaultContract,
    deployTokenContract,
    mineBlocks
}
