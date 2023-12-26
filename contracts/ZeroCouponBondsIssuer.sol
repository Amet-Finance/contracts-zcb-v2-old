// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IAmetVault} from "./interfaces/IAmetVault.sol";
import {CoreTypes} from "./libraries/CoreTypes.sol";
import {ZeroCouponBonds} from "./ZeroCouponBonds.sol";

contract ZeroCouponBondsIssuer is Ownable {
    struct ContractPackedInfo {
        uint8 purchaseFeePercentage;
        uint8 earlyRedemptionFeePercentage;
        bool isPaused;
    }
  
    enum FeeTypes {
        Issuance,
        EarlyRedemption,
        VaultPurchase,
        ReferrerPurchase
    }

    event Issue(address indexed contractAddress);
    event PauseChanged(bool isPaused);
    event FeeChanged(FeeTypes feeType, uint256 oldFee, uint256 newFee);

    error TransferFailed();
    error MissingFee();
    error ContractPaused();

    address public vault;
    uint256 public issuanceFee;

    ContractPackedInfo public contractPackedInfo;

    modifier notPaused() {
        if (contractPackedInfo.isPaused) revert ContractPaused();
        _;
    }

    constructor(
        uint256 _initialIssuanceFee,
        uint8 _initialVaultPurchaseFeePercentage,
        uint8 _initialEarlyRedemptionFeePercentage
    ) Ownable(msg.sender) {
        issuanceFee = _initialIssuanceFee;
        contractPackedInfo = ContractPackedInfo(_initialVaultPurchaseFeePercentage, _initialEarlyRedemptionFeePercentage, false);
    }

    function issueBonds(
        uint40 total,
        uint40 maturityThreshold,
        address investmentToken,
        uint256 investmentAmount,
        address interestToken,
        uint256 interestAmount,
        address referrer
    ) external payable notPaused {
        
        if (msg.value != issuanceFee) revert MissingFee();
        (bool success,) = owner().call{value: issuanceFee}("");
        if (!success) revert TransferFailed();

        ZeroCouponBonds bondContract = new ZeroCouponBonds({
            _initialIssuer: msg.sender,
            _initialVault: vault,

            _initialBondInfo: CoreTypes.BondInfo(total, 0, 0, 0, maturityThreshold, false, false, contractPackedInfo.purchaseFeePercentage, contractPackedInfo.earlyRedemptionFeePercentage),

            _initialInvestmentToken: investmentToken,
            _initialInvestmentAmount: investmentAmount,

            _initialInterestToken: interestToken,
            _initialInterestAmount: interestAmount
        });


        if (address(referrer) != address(0)) {
            IAmetVault(vault).setReferrer(address(bondContract), referrer);
        }

        emit Issue(address(bondContract));
    }

    function changePausedState(bool pausedState) external onlyOwner {
        emit PauseChanged(pausedState);
        contractPackedInfo.isPaused = pausedState;
    }

    function changeIssuanceFee(uint256 fee) external onlyOwner {
        emit FeeChanged(FeeTypes.Issuance, issuanceFee, fee);
        issuanceFee = fee;
    }

    function changeEarlyRedemptionFeePercentage(uint8 fee) external onlyOwner {
        emit FeeChanged(FeeTypes.EarlyRedemption, contractPackedInfo.earlyRedemptionFeePercentage, fee);
        contractPackedInfo.earlyRedemptionFeePercentage = fee;
    }

    function changeVaultPurchaseFeePercentage(uint8 fee) external onlyOwner {
        emit FeeChanged(FeeTypes.VaultPurchase, contractPackedInfo.purchaseFeePercentage, fee);
        contractPackedInfo.purchaseFeePercentage = fee;
    }    

    function changeVaultAddress(address newVault) external onlyOwner {
        vault = newVault;
    } 
}
