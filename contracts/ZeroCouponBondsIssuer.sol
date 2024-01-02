// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {CoreTypes} from "./libraries/CoreTypes.sol";
import {ZeroCouponBonds} from "./ZeroCouponBonds.sol";

contract ZeroCouponBondsIssuer is Ownable {
    struct ContractPackedInfo {
        uint8 purchaseFeePercentage;
        uint8 earlyRedemptionFeePercentage;
        bool isPaused;
    }

    enum FeeTypes {
        IssuanceFee,
        EarlyRedemptionFeePercentage,
        PurchaseFeePercentage
    }

    event Issue(address indexed contractAddress);
    event VaultChanged(address newVault);
    event PauseChanged(bool isPaused);
    event FeeChanged(FeeTypes feeType, uint256 fee);

    error MissingFee();
    error ContractPaused();

    address public vault;
    uint256 public issuanceFee;
    ContractPackedInfo public contractPackedInfo;
    mapping(address => bool) public issuedContracts;

    constructor(
        uint256 _initialIssuanceFee,
        uint8 _initialVaultPurchaseFeePercentage,
        uint8 _initialEarlyRedemptionFeePercentage
    ) Ownable(msg.sender) {
        issuanceFee = _initialIssuanceFee;
        contractPackedInfo = ContractPackedInfo(_initialVaultPurchaseFeePercentage, _initialEarlyRedemptionFeePercentage, false);
    }

    function issueBondContract(
        uint40 total,
        uint40 maturityThreshold,
        address investmentToken,
        uint256 investmentAmount,
        address interestToken,
        uint256 interestAmount
    ) external payable {
        ContractPackedInfo memory packedInfoLocal = contractPackedInfo;
        if (packedInfoLocal.isPaused) revert ContractPaused();

        (bool success,) = owner().call{value: issuanceFee}("");
        if (!success) revert MissingFee();

        ZeroCouponBonds bondContract = new ZeroCouponBonds({
            _initialIssuer: msg.sender,
            _initialVault: vault,

            _initialBondInfo: CoreTypes.BondInfo({
                    total: total,
                    purchased: 0,
                    redeemed: 0,
                    uniqueBondIndex: 0,
                    maturityThreshold: maturityThreshold,
                    isSettled: false,
                    purchaseFeePercentage: packedInfoLocal.purchaseFeePercentage,
                    earlyRedemptionFeePercentage: packedInfoLocal.earlyRedemptionFeePercentage
            }),

            _initialInvestmentToken: investmentToken,
            _initialInvestmentAmount: investmentAmount,

            _initialInterestToken: interestToken,
            _initialInterestAmount: interestAmount
        });

        address bondContractAddress = address(bondContract);
        issuedContracts[bondContractAddress] = true;

        emit Issue(bondContractAddress);
    }

    ///////////////////////////////////
    //     Only owner functions     //
    /////////////////////////////////

    function changePausedState(bool isPaused) external onlyOwner {
        contractPackedInfo.isPaused = isPaused;
        emit PauseChanged(isPaused);
    }

    function changeIssuanceFee(uint256 fee) external onlyOwner {
        issuanceFee = fee;
        emit FeeChanged(FeeTypes.IssuanceFee, fee);
    }

    function changeEarlyRedemptionFeePercentage(uint8 fee) external onlyOwner {
        contractPackedInfo.earlyRedemptionFeePercentage = fee;
        emit FeeChanged(FeeTypes.EarlyRedemptionFeePercentage, fee);

    }

    function changePurchaseFeePercentage(uint8 fee) external onlyOwner {
        contractPackedInfo.purchaseFeePercentage = fee;
        emit FeeChanged(FeeTypes.PurchaseFeePercentage, fee);
    }

    function changeVaultAddress(address newVault) external onlyOwner {
        emit VaultChanged(newVault);
        vault = newVault;
    }
}
