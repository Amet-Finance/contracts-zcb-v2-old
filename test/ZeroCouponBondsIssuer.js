const { ethers } = require("hardhat");
const { expect } = require("chai");
const { randomAddress } = require("hardhat/internal/hardhat-network/provider/utils/random");
const { deployIssuerContract, issuerContractDefaultParams } = require("./utils");

describe("ZeroCouponBondsIssuer", function () {
  it("Deploy Issuer Contract", async () => {
    await deployIssuerContract();
  })

  it("Check Public Variables", async () => {
    const signers = await ethers.getSigners();
    const issuerContract = await deployIssuerContract();

    const {
      initialFee,
      initialVaultPurchaseFeePercentage,
      initialEarlyRedemptionFeePercentage
    } = issuerContractDefaultParams();

    const owner = await issuerContract.owner();
    const issuanceFee = await issuerContract.issuanceFee();
    const contractPackedInfo = await issuerContract.contractPackedInfo();
    const vault = await issuerContract.vault();

    const isTrue =
        issuanceFee === initialFee &&
        owner === signers[0].address &&
        contractPackedInfo.purchaseFeePercentage === initialVaultPurchaseFeePercentage &&
        contractPackedInfo.earlyRedemptionFeePercentage === initialEarlyRedemptionFeePercentage &&
        contractPackedInfo.isPaused === false &&
        vault.toLowerCase() === ethers.ZeroAddress


    expect(isTrue).to.equal(true)
  })

  it("Change Pause State", async () => {
    const signers = await ethers.getSigners();
    const owner = signers[0];
    const issuerContract = await deployIssuerContract();
    issuerContract.connect(owner);

    await issuerContract.changePausedState(true);
    const contractPackedInfo = await issuerContract.contractPackedInfo();

    let bondCreationFailed = false;


    await issuerContract.issueBondContract(100, 0, randomAddress().toString(), 0, randomAddress().toString(), 0)
      .catch(error => {
        if (error.message.includes("ContractPaused")) bondCreationFailed = true
      })

    const isTrue = contractPackedInfo.isPaused === true && bondCreationFailed

    expect(isTrue).to.equal(true)
  })

  it("Change Issuance Fee", async () => {
    [owner] = await ethers.getSigners();

    const issuerContract = await deployIssuerContract();
    issuerContract.connect(owner);

    const fee = BigInt(10)
    await issuerContract.changeIssuanceFee(fee);
    const issuanceFee = await issuerContract.issuanceFee();

    expect(issuanceFee).to.equal(fee)
  })

  it("Change Early Redemption Fee Percentage", async () => {
    const signers = await ethers.getSigners();
    const owner = signers[0];

    const issuerContract = await deployIssuerContract();
    issuerContract.connect(owner);

    const newPercentage = BigInt(10)
    await issuerContract.changeEarlyRedemptionFeePercentage(newPercentage);
    const contractPackedInfo = await issuerContract.contractPackedInfo();

    expect(contractPackedInfo.earlyRedemptionFeePercentage).to.equal(newPercentage)
  })

  it("Change Purchase Fee Percentage", async () => {
    const signers = await ethers.getSigners();
    const owner = signers[0];

    const issuerContract = await deployIssuerContract();
    issuerContract.connect(owner);

    const newPercentage = BigInt(10)
    await issuerContract.changePurchaseFeePercentage(newPercentage);
    const contractPackedInfo = await issuerContract.contractPackedInfo();

    expect(contractPackedInfo.purchaseFeePercentage).to.equal(newPercentage)
  })

  it("Change Vault Address", async () => {
    const signers = await ethers.getSigners();
    const owner = signers[0];

    const issuerContract = await deployIssuerContract();
    issuerContract.connect(owner);

    const vaultOld = await issuerContract.vault();
    if (vaultOld !== ethers.ZeroAddress) throw Error("Address is invalid");

    const newAddress = randomAddress().toString()
    await issuerContract.changeVaultAddress(newAddress);

    await issuerContract.changeVaultAddress(ethers.ZeroAddress).catch(error => {
      if (!error.message.includes("ZeroAddress")) throw Error('Zero check did not pass')
    });

    const vaultNew = await issuerContract.vault();

    expect(vaultNew).to.equal(ethers.getAddress(newAddress))
  })

  it("Change Owner", async () => {
    [owner, newOwner] = await ethers.getSigners();

    const issuerContract = await deployIssuerContract();
    issuerContract.connect(owner);

    await issuerContract.transferOwnership(newOwner.address);
    const newOwnerAddress = await issuerContract.owner();

    await issuerContract.changeVaultAddress(ethers.ZeroAddress).catch(error => {
      if (!error.message.includes("OwnableUnauthorizedAccount")) throw Error("Did not change")
    })

    expect(newOwnerAddress.toLowerCase()).to.be.equal(newOwner.address.toLowerCase())
  })

  it("Issue Bonds", async () => {
    [owner] = await ethers.getSigners();
    const issuerContract = await deployIssuerContract();
    issuerContract.connect(owner);

    const total = BigInt(10);
    const maturityThreshold = BigInt(20)


    const tokenContract = randomAddress().toString()
    const investmentAmount = BigInt(10) * BigInt(1e18)
    const interestAmount = BigInt(15) * BigInt(1e18)

    let isRevertedForMissingFee = false

    await issuerContract.issueBondContract(total, maturityThreshold, tokenContract, investmentAmount, tokenContract, interestAmount)
        .catch(error => {
          if (error.message.includes("MissingFee")) isRevertedForMissingFee = true;
        })

    const isTrue = isRevertedForMissingFee;

    await issuerContract.issueBondContract(total, maturityThreshold, tokenContract, investmentAmount, tokenContract, interestAmount, {
      value: issuerContractDefaultParams().initialFee
    });
    expect(isTrue).to.be.equal(true);
  })
});
