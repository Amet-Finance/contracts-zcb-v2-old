// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

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
        IssuanceFee,
        EarlyRedemptionFeePercentage,
        PurchaseFeePercentage
    }

    event Issue(address indexed contractAddress);
    event VaultChanged(address newVault);
    event PauseChanged(bool isPaused);
    event FeeChanged(FeeTypes feeType, uint256 fee);

    error ContractPaused();

    address public vault;
    ContractPackedInfo public contractPackedInfo;
    mapping(address bondContract => bool exists) public issuedContracts;

    constructor(
        uint8 _initialVaultPurchaseFeePercentage,
        uint8 _initialEarlyRedemptionFeePercentage
    ) Ownable(msg.sender) {
        contractPackedInfo = ContractPackedInfo(_initialVaultPurchaseFeePercentage, _initialEarlyRedemptionFeePercentage, false);
    }

    /// @dev Issues bonds contract
    /// @param total - Total count of bonds
    /// @param maturityPeriod - Blocks that are required to bass so the bond can become mature
    /// @param investmentToken - The investment token
    /// @param investmentAmount - The investment amount to purchase 1 bond
    /// @param interestToken - The interest token
    /// @param investmentAmount - The interest amount that one will receive for 1 bond upon redeeming
    function issueBondContract(
        uint40 total,
        uint40 maturityPeriod,
        address investmentToken,
        uint256 investmentAmount,
        address interestToken,
        uint256 interestAmount
    ) external payable {
        ContractPackedInfo memory packedInfoLocal = contractPackedInfo;
        if (packedInfoLocal.isPaused) revert ContractPaused();

        IAmetVault(vault).depositInssuanceFee{value: msg.value}();

        CoreTypes.notZeroAddress(investmentToken);
        CoreTypes.notZeroAddress(interestToken);

        ZeroCouponBonds bondContract = new ZeroCouponBonds({
            _initialIssuer: msg.sender,

            _initialBondInfo: CoreTypes.BondInfo({
                    total: total,
                    purchased: 0,
                    redeemed: 0,
                    uniqueBondIndex: 0,
                    maturityPeriod: maturityPeriod,
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

    /// @dev Changes the paused state
    /// @param isPaused - bool
    function changePausedState(bool isPaused) external onlyOwner {
        contractPackedInfo.isPaused = isPaused;
        emit PauseChanged(isPaused);
    }

    /// @dev Changes the early redemption fee percentage for the upcoming bonds
    /// @param fee - new fee
    function changeEarlyRedemptionFeePercentage(uint8 fee) external onlyOwner {
        contractPackedInfo.earlyRedemptionFeePercentage = fee;
        emit FeeChanged(FeeTypes.EarlyRedemptionFeePercentage, fee);
    }

    /// @dev Changes the purchase fee percentage for the upcoming bonds
    /// @param fee - new fee
    function changePurchaseFeePercentage(uint8 fee) external onlyOwner {
        contractPackedInfo.purchaseFeePercentage = fee;
        emit FeeChanged(FeeTypes.PurchaseFeePercentage, fee);
    }

    /// @dev Changes the vault contract address
    /// @param newVault - new contract address of the new vault
    function changeVaultAddress(address newVault) external onlyOwner {
        CoreTypes.notZeroAddress(newVault);
        vault = newVault;
        emit VaultChanged(newVault);
    }
}
