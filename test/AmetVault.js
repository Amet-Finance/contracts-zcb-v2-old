
const { expect } = require("chai");
const { ethers } = require("hardhat");
const {deployIssuerWithVaultContract} = require("./utils");
const {randomAddress} = require("hardhat/internal/hardhat-network/provider/utils/random");

// get
// referrers, owner, issuerContract,

// post
// withdrawETH, withdrawERC20,
// transferOwnership, recordReferral, claimReferralPurchase, changeReferralPurchaseFee

describe("Amet Vault", function () {

    it("Deploy Vault Contract", async () => {
        [deployer] = await ethers.getSigners();
        const {issuerContract, valutContract} = await deployIssuerWithVaultContract(deployer);
        expect(valutContract.target).to.be.properAddress;
    })


    it('Withdraw ETH', async () => {
        [deployer, customAddress] = await ethers.getSigners();
        const {issuerContract, valutContract} = await deployIssuerWithVaultContract(deployer);
        await deployer.sendTransaction({
            to: valutContract.target,
            value: BigInt(1) * BigInt(1e18)
        })

        const vaultMutated = await valutContract.connect(customAddress);
        await vaultMutated.withdrawETH(randomAddress().toString(), BigInt(1e18))
            .then(() => {
                throw Error("Only owner check passed")
            })
            .catch(error => {
                if (!error.message.includes('OwnableUnauthorizedAccount')) {
                    throw Error("Only owner check passed")
                }
            })

        await valutContract.withdrawETH(randomAddress().toString(), BigInt(1e18));
    });

    it('Withdraw ERC20', async () => {
        [deployer, customAddress] = await ethers.getSigners();
        const {issuerContract, valutContract} = await deployIssuerWithVaultContract(deployer);
        await deployer.sendTransaction({
            to: valutContract.target,
            value: BigInt(1) * BigInt(1e18)
        })

        const vaultMutated = await valutContract.connect(customAddress);
        await vaultMutated.withdrawETH(randomAddress().toString(), BigInt(1e18))
            .then(() => {
                throw Error("Only owner check passed")
            })
            .catch(error => {
                if (!error.message.includes('OwnableUnauthorizedAccount')) {
                    throw Error("Only owner check passed")
                }
            })

        await valutContract.withdrawETH(randomAddress().toString(), BigInt(1e18));
    });

});
