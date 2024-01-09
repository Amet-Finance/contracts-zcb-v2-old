const {
    deployIssuerContract,
    deployTokenContract,
    issuerContractDefaultParams,
    mineBlocks,
    deployVaultContract
} = require("./utils");
const {ethers} = require("hardhat");
const {expect} = require("chai");
const ZCB_ABI = require('../artifacts/contracts/ZeroCouponBonds.sol/ZeroCouponBonds.json').abi

describe("ZeroCouponBonds", () => {
    let tokenContract;
    const accounts = {}

    before(async () => {
        const signers = await ethers.getSigners();
        signers.forEach((account, index) => {
            accounts[`account${index + 1}`] = account;
        })

        tokenContract = await deployTokenContract(accounts.account1);
    })

    it("Issue Bond", async () => {
        const issuerContract = await deployIssuerContract();
        issuerContract.connect(accounts.account1);

        const total = BigInt(10);
        const maturityThreshold = BigInt(20)


        const investmentAmount = BigInt(10) * BigInt(1e18)
        const interestAmount = BigInt(15) * BigInt(1e18)

        let isRevertedForMissingFee = false

        await issuerContract.issueBondContract(total, maturityThreshold, tokenContract.target, investmentAmount, tokenContract.target, interestAmount)
            .catch(error => {
                if (error.message.includes("MissingFee")) isRevertedForMissingFee = true;
            })

        const isTrue = isRevertedForMissingFee;

        await issuerContract.issueBondContract(total, maturityThreshold, tokenContract.target, investmentAmount, tokenContract.target, interestAmount, {
            value: issuerContractDefaultParams().initialFee
        });
        expect(isTrue).to.be.equal(true);
    })

    it("Purchase Bond and Redeem", async () => {
        const issuerContract = await deployIssuerContract();
        issuerContract.connect(accounts.account1);

        const vault = await deployVaultContract(issuerContract.target);
        await issuerContract.changeVaultAddress(vault.target);

        const total = BigInt(10);
        const maturityThreshold = BigInt(20)


        const investmentAmount = BigInt(10) * BigInt(1e18)
        const interestAmount = BigInt(15) * BigInt(1e18)


        const promise = await issuerContract.issueBondContract(total, maturityThreshold, tokenContract.target, investmentAmount, tokenContract.target, interestAmount, {
            value: issuerContractDefaultParams().initialFee
        });

        const provider = ethers.provider;
        const txReceipt = await provider.getTransactionReceipt(promise.hash);

        let bondContractTarget;
        for (const log of txReceipt.logs) {
            const decodedData = issuerContract.interface.parseLog({
                topics: [...log.topics],
                data: log.data
            });

            if (decodedData.name === "Issue") {
                bondContractTarget = decodedData.args.contractAddress
            }
        }

        let bondContract = new ethers.Contract(bondContractTarget, ZCB_ABI, provider);
        const purchaseCount = BigInt(10)


        tokenContract.connect(accounts.account1)
        await tokenContract.approve(bondContractTarget, purchaseCount * investmentAmount);


        bondContract = bondContract.connect(accounts.account1)

        await bondContract.purchase(purchaseCount, ethers.ZeroAddress)

        const bondInfo = await bondContract.bondInfo();
        if (bondInfo.purchased !== purchaseCount) throw Error("Invalid Purchase")

        await mineBlocks(provider, bondInfo.maturityThreshold);
        await tokenContract.transfer(bondContractTarget, purchaseCount * interestAmount);

        await bondContract.redeem([0], purchaseCount, false)

        const bondInfo2 = await bondContract.bondInfo();
        if (bondInfo2.redeemed !== purchaseCount) throw Error("Invalid Purchase")

        expect(bondInfo2.redeemed).to.be.equal(purchaseCount)
    })

})
