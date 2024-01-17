const {
    deployIssuerContract,
    deployTokenContract,
    issuerContractDefaultParams,
    mineBlocks,
    deployVaultContract, assignBondContract, deployIssuerWithVaultContract, issueBondContract
} = require("./utils");
const {ethers} = require("hardhat");
const {expect} = require("chai");

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

    it("Purchase Bond and Redeem", async () => {
        const {issuerContract, valutContract} = await deployIssuerWithVaultContract(undefined, accounts.account1);

        const params = {
            total: BigInt(10),
            maturityPeriod: BigInt(20),
            investmentToken: tokenContract.target,
            investmentAmount: BigInt(10) * BigInt(1e18),
            interestToken: tokenContract.target,
            interestAmount: BigInt(15) * BigInt(1e18),
        }
        const bondContract = await issueBondContract(issuerContract, params, accounts.account1)


        const purchaseCount = BigInt(10)
        await tokenContract.approve(bondContract.target, purchaseCount * params.investmentAmount);
        await bondContract.purchase(purchaseCount, ethers.ZeroAddress)

        // Check for purchasing more
        await bondContract.purchase(1, ethers.ZeroAddress)
            .then(() => {
                throw Error('Purchased more than required')
            })
            .catch(error => {
                if (!error.message.includes("OperationFailed(2)")) throw Error('Purchased more than required')
            })


        const purchaseBondInfo = await bondContract.bondInfo();
        if (purchaseBondInfo.purchased !== purchaseCount) throw Error("Invalid Purchase")

        // mine blocks to meet maturity and transfer the amount to meet interest
        await mineBlocks(params.maturityPeriod);
        await tokenContract.transfer(bondContract.target, purchaseCount * params.interestAmount);

        // as we purchase all the token id is 0 with balance of 10
        await bondContract.redeem([0], purchaseCount, false)

        const redeemBondInfo = await bondContract.bondInfo();
        if (redeemBondInfo.redeemed !== purchaseCount) throw Error("Invalid Redeem")


        // Check for redeeming more
        await bondContract.redeem([0], BigInt(1), true)
            .then(() => {
                throw Error('Redeemed more than could')
            })
            .catch(error => {
                // console.log(error);
            })
    })

})


