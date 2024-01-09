
const { expect } = require("chai");
const { ethers } = require("hardhat");
const {deployIssuerWithVaultContract} = require("./utils");

describe("Amet Vault", function () {


    it("Deploy Vault Contract", async () => {
        [deployer] = await ethers.getSigners();
        const {issuerContract, valutContract} = await deployIssuerWithVaultContract(deployer);
        expect(valutContract.target).to.be.properAddress;
    })
});
