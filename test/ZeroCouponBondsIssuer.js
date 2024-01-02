const {ethers} = require("hardhat");
const {expect} = require("chai");
const {address} = require("hardhat/internal/core/config/config-validation");
const {randomAddress} = require("hardhat/internal/hardhat-network/provider/utils/random");
const {zeroOutAddresses} = require("hardhat/internal/hardhat-network/stack-traces/library-utils");

describe("ZeroCouponBondsIssuer", function () {

  const constants = {
    provider: null,

    issuerContract: null,
    tokenContract: null,

    initialFee: 0,
  }

  before(async function () {
    const initialFee = 1e18.toString();
    const initialVaultPurchaseFeePercentage = 50;
    const initialEarlyRedemptionFeePercentage = 25;

    constants.issuerContract = await ethers.deployContract("ZeroCouponBondsIssuer", [initialFee, initialVaultPurchaseFeePercentage, initialEarlyRedemptionFeePercentage]);
    constants.tokenContract = await ethers.deployContract("Token", []);
    constants.vaultContract = await ethers.deployContract("AmetVault", [constants.issuerContract.target]);

    await constants.issuerContract.changeVaultAddress(constants.vaultContract.target);

    constants.initialFee = initialFee;
    constants.provider = constants.issuerContract.runner.provider;
  });


  /////////////////////////////////
  //        Checking ZCB        //
  ///////////////////////////////

  it("Issuing Bond", async function () {

    const [issuerContractOwner, bondContractOwner] = await ethers.getSigners();
    const contract = constants.issuerContract.connect(issuerContractOwner)

    const owner = await contract.owner();
    const ownerBalanceBefore = await constants.provider.getBalance(owner);

    const response = await contract.issueBondContract(100, 50, constants.tokenContract.target, 10, constants.tokenContract.target, 10, {
      value: constants.initialFee
    });


    const ownerBalanceAfter = await constants.provider.getBalance(owner);
    const difference = (ownerBalanceAfter - ownerBalanceBefore) / BigInt(1e18)

    await response.wait();

    const tx = await constants.provider.getTransactionReceipt(response.hash);
    console.log(tx)
    for (const log of tx.logs) {
      const decodedData = contract.interface.parseLog({
        topics: [...log.topics],
        data: log.data
      });


      if (decodedData.name === "Issue") {
        constants.bondContract = new ethers.Contract(decodedData.args.contractAddress, require('../artifacts/contracts/ZeroCouponBonds.sol/ZeroCouponBonds.json').abi, constants.provider);
      }
    }

    const bondContract = constants.bondContract.connect(bondContractOwner);



    const bondInfo = parseBondInfo(await bondContract.bondInfo());
    console.log(bondInfo);
    expect(difference).to.equal(BigInt(constants.initialFee / 1e18))
  });

  it("Purchase Bond", async () => {
    const [owner, random1] = await ethers.getSigners();
    const tokenContract = constants.tokenContract.connect(owner);

    await tokenContract.transfer(random1.address, BigInt(400000) * BigInt(1e18));
    const balanceOF = await tokenContract.balanceOf(random1.address);


    const bondContract = constants.bondContract.connect(random1);

    const count = 10;
    const investmentAmount = await bondContract.investmentAmount();
    const tokenWithRandom = constants.tokenContract.connect(random1);
    await tokenWithRandom.approve(bondContract.target, BigInt(count) * BigInt(investmentAmount));
    const purchase = await bondContract.purchase(count, "0x0000000000000000000000000000000000000000");


    const bondInfo = parseBondInfo(await bondContract.bondInfo());
    console.log(balanceOF)

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
