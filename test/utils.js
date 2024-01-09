const {ethers} = require("hardhat");
const ZCB_ABI = require('../artifacts/contracts/ZeroCouponBonds.sol/ZeroCouponBonds.json').abi

async function mineBlocks(count = BigInt(1)) {
    const provider = ethers.provider;

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

async function deployIssuerWithVaultContract(params, account) {
    const issuerContract = await deployIssuerContract(params, account);
    issuerContract.connect(account);
    const valutContract = await deployVaultContract(issuerContract.target, account);
    await issuerContract.changeVaultAddress(valutContract.target);
    return {
        issuerContract,
        valutContract
    }
}

async function deployIssuerContract(params, account) {
    const defaultParams = issuerContractDefaultParams()
    const initialFee = params?.initialFee || defaultParams.initialFee
    const initialVaultPurchaseFeePercentage = params?.initialVaultPurchaseFeePercentage || defaultParams.initialVaultPurchaseFeePercentage;
    const initialEarlyRedemptionFeePercentage = params?.initialEarlyRedemptionFeePercentage || defaultParams.initialEarlyRedemptionFeePercentage;
    const contract = await ethers.deployContract("ZeroCouponBondsIssuer", [initialFee, initialVaultPurchaseFeePercentage, initialEarlyRedemptionFeePercentage]);

    if (account) {
        return contract.connect(account);
    }

    return contract;
}

async function deployVaultContract(issuerContract, account) {
    const contract = await ethers.deployContract("AmetVault", [issuerContract]);
    if (account) return contract.connect(account);
    return contract;
}

async function deployTokenContract(account) {
    const contract = await ethers.deployContract("Token", []);

    if (account) return contract.connect(account);
    return contract;
}

function assignBondContract(bondContractTarget, account) {
    const provider = ethers.provider;
    const contract = new ethers.Contract(bondContractTarget, ZCB_ABI, provider);

    if (account) return contract.connect(account);
    return contract
}


////////////////////////////////
/// Bond Contract functions ///
//////////////////////////////

async function issueBondContract(issuerContract, params, account) {
    const {total, maturityThreshold, investmentToken, investmentAmount, interestToken, interestAmount} = params;
    const promise = await issuerContract.issueBondContract(total, maturityThreshold, investmentToken, investmentAmount, interestToken, interestAmount, {
        value: issuerContractDefaultParams().initialFee
    });

    const bondContractTarget = await getBondTargetFromLogs(issuerContract, promise.hash)


    return assignBondContract(bondContractTarget, account)
}

async function getBondTargetFromLogs(issuerContract, hash) {
    const provider = ethers.provider;
    const txReceipt = await provider.getTransactionReceipt(hash);

    for (const log of txReceipt.logs) {
        const decodedData = issuerContract.interface.parseLog({
            topics: [...log.topics],
            data: log.data
        });

        if (decodedData.name === "Issue") {
            return decodedData.args.contractAddress
        }
    }
}



module.exports = {
    issuerContractDefaultParams,
    deployIssuerWithVaultContract,
    deployIssuerContract,
    deployVaultContract,
    deployTokenContract,
    assignBondContract,
    mineBlocks,

    issueBondContract,
}
