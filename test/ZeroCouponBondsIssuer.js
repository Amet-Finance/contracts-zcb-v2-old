const { ethers } = require("hardhat");
const { expect } = require("chai");
const { address } = require("hardhat/internal/core/config/config-validation");
const { randomAddress } = require("hardhat/internal/hardhat-network/provider/utils/random");
const { zeroOutAddresses } = require("hardhat/internal/hardhat-network/stack-traces/library-utils");
const { deployIssuerContract, issuerContractDefaultParams } = require("./utils");

describe("ZeroCouponBondsIssuer", function () {


  // before(async function () {
  //   const initialFee = 1e18.toString();
  //   const initialVaultPurchaseFeePercentage = 50;
  //   const initialEarlyRedemptionFeePercentage = 25;
  //
  //   constants.issuerContract = await ethers.deployContract("ZeroCouponBondsIssuer", [initialFee, initialVaultPurchaseFeePercentage, initialEarlyRedemptionFeePercentage]);
  //   constants.tokenContract = await ethers.deployContract("Token", []);
  //   constants.vaultContract = await ethers.deployContract("AmetVault", [constants.issuerContract.target]);
  //
  //   await constants.issuerContract.changeVaultAddress(constants.vaultContract.target);
  //
  //   constants.initialFee = initialFee;
  //   constants.provider = constants.issuerContract.runner.provider;
  // });


  /////////////////////////////////
  //        Checking ZCB        //
  ///////////////////////////////

  // it("Issuing Bond", async function () {
  //
  //   const [issuerContractOwner, bondContractOwner] = await ethers.getSigners();
  //   const contract = constants.issuerContract.connect(issuerContractOwner)
  //
  //   const owner = await contract.owner();
  //   const ownerBalanceBefore = await constants.provider.getBalance(owner);
  //
  //   const investmentAmount = BigInt(10) * BigInt(1e18)
  //   const interestAmount = BigInt(15) * BigInt(1e18)
  //
  //   const response = await contract.issueBondContract(100, 50, constants.tokenContract.target, investmentAmount, constants.tokenContract.target, interestAmount, {
  //     value: constants.initialFee
  //   });
  //
  //
  //   const ownerBalanceAfter = await constants.provider.getBalance(owner);
  //   const difference = (ownerBalanceAfter - ownerBalanceBefore) / BigInt(1e18)
  //
  //   await response.wait();
  //
  //   const tx = await constants.provider.getTransactionReceipt(response.hash);
  //   console.log(tx)
  //   for (const log of tx.logs) {
  //     const decodedData = contract.interface.parseLog({
  //       topics: [...log.topics],
  //       data: log.data
  //     });
  //
  //
  //     if (decodedData.name === "Issue") {
  //       constants.bondContract = new ethers.Contract(decodedData.args.contractAddress, require('../artifacts/contracts/ZeroCouponBonds.sol/ZeroCouponBonds.json').abi, constants.provider);
  //     }
  //   }
  //
  //   const bondContract = constants.bondContract.connect(bondContractOwner);
  //
  //
  //
  //   const bondInfo = parseBondInfo(await bondContract.bondInfo());
  //   console.log(bondInfo);
  //   expect(difference).to.equal(BigInt(constants.initialFee / 1e18))
  // });
  //
  // it("Purchase Bond and redeem", async () => {
  //   const [owner, random1] = await ethers.getSigners();
  //   const tokenContract = constants.tokenContract.connect(owner);
  //
  //   await tokenContract.transfer(random1.address, BigInt(400000) * BigInt(1e18));
  //   const balanceOF = await tokenContract.balanceOf(random1.address);
  //
  //
  //   const bondContract = constants.bondContract.connect(random1);
  //
  //   const count = 10;
  //   const investmentAmount = await bondContract.investmentAmount();
  //   const tokenWithRandom = constants.tokenContract.connect(random1);
  //   await tokenWithRandom.approve(bondContract.target, BigInt(count) * BigInt(investmentAmount));
  //   const purchase = await bondContract.purchase(count, "0x0000000000000000000000000000000000000000");
  //
  //   const txReceipt = await constants.provider.getTransactionReceipt(purchase.hash);
  //   const balances = {}
  //   for (const log of txReceipt.logs) {
  //     const decodedData = constants.bondContract.interface.parseLog({
  //       topics: [...log.topics],
  //       data: log.data
  //     });
  //
  //
  //     if (decodedData?.name === "TransferSingle") {
  //       balances[decodedData.args.id] = decodedData.args.value;
  //       // constants.bondContract = new ethers.Contract(decodedData.args.contractAddress, require('../artifacts/contracts/ZeroCouponBonds.sol/ZeroCouponBonds.json').abi, constants.provider);
  //     }
  //   }
  //   const block1 = await constants.provider.getBlockNumber()
  //   await mineBlocks(51);
  //   const block2 = await constants.provider.getBlockNumber()
  //   console.log(block1, block2)
  //
  //   const bondInfo = parseBondInfo(await bondContract.bondInfo());
  //
  //   const interestAmount = BigInt(15) * BigInt(1e18)
  //   constants.tokenContract.transfer(bondContract.target, interestAmount * BigInt(10))
  //   const purchaseBlock = await bondContract.bondPurchaseBlocks(0);
  //   await bondContract.redeem([0], 10, false);
  //
  //   const bondInfo1 = parseBondInfo(await bondContract.bondInfo());
  //   console.log(balanceOF)
  //
  // })


  it("Deploy Issuer Contract", async () => {
    await deployIssuerContract();
  })

  it("Check Variables", async () => {
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

    const isTrue = issuanceFee === initialFee && owner === signers[0].address && contractPackedInfo.purchaseFeePercentage === initialVaultPurchaseFeePercentage && contractPackedInfo.earlyRedemptionFeePercentage === initialEarlyRedemptionFeePercentage && contractPackedInfo.isPaused === false

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

});


function parseBondInfo(response) {
  return {
    total: response[0],
    purchased: response[1],
    redeemed: response[2],
    uniqueBondIndex: response[3],
    maturityThreshold: response[4],
    isSettled: response[5],
    purchaseFeePercentage: response[6],
    earlyRedemptionFeePercentage: response[7]
  }
}
