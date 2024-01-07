const {deployIssuerContract, deployTokenContract} = require("./utils");
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

        // const response = await issuerContract.issueBondContract(total, maturityThreshold, tokenContract.target, investmentAmount, tokenContract.target, interestAmount);
        // console.log(response)
        expect(isTrue).to.be.equal(true);
    })

})
