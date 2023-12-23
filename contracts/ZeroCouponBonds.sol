// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
/**
 * 00000000 00    00 00000000 00000000
 * 00    00 000  000 00          00
 * 00    00 00 00 00 00          00
 * 00    00 00    00 00          00
 * 00000000 00    00 00000000    00
 * 00    00 00    00 00          00
 * 00    00 00    00 00          00
 * 00    00 00    00 00000000    00
 *
 *
 *
 * @title Amet Finance ZeroCouponBondsV2
 * @dev
 *
 * Author: @TheUnconstrainedMind
 * Created: 20 Dec 2023
 *
 * Optional:
 * -
 */

import {CoreTypes} from "./base/CoreTypes.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

contract ZeroCouponBonds is ERC1155 {
    using SafeERC20 for IERC20;

    enum OperationCodes {
        OnlyReferrer,
        TransferFailed,
        InsufficientLiquidity,
        RedemptionBeforeMaturity,
        InvalidAccess,
        ContractAlreadySettled,
        InvalidAddress,
        InvalidAction
    }

    error OperationFailed(OperationCodes code);

    CoreTypes.BondRoles private _bondRoles;
    CoreTypes.BondInfo private _bondInfo;
    CoreTypes.BondLifecycle private _bondLifecycle;

    CoreTypes.FeeInfo private _feeInfo;

    CoreTypes.TokenInfo private _investment;
    CoreTypes.TokenInfo private _interest;

    /// @dev The amount that the referrer will receive after the contract is settled
    uint256 private _referralCompletionBonus;

    /// @dev tokenId => blockNumber: the block when the bond(s) was(were) purchased
    mapping(uint40 => uint256) private _bondPurchaseBlocks;

    modifier onlyVaultOwner() {
        if (msg.sender != _bondRoles.vault) revert CoreTypes.OnlyVaultOwner();
        _;
    }

    modifier onlyIssuer() {
        if (msg.sender != _bondRoles.issuer) revert CoreTypes.OnlyIssuer();
        _;
    }

    modifier validAddress(address _addr) {
        if (_addr == address(0)) revert OperationFailed(OperationCodes.InvalidAddress);
        _;
    }

    modifier notSettled() {
        if (_bondInfo.isSettled) revert OperationFailed(OperationCodes.ContractAlreadySettled);
        _;
    }

    constructor(
        CoreTypes.BondRoles memory _initialBondRoles,
        CoreTypes.BondInfo memory _initialBondInfo,
        CoreTypes.BondLifecycle memory _initialBondLifecycle,
        CoreTypes.FeeInfo memory _initialFeeInfo,
        CoreTypes.TokenInfo memory _initialInvestment,
        CoreTypes.TokenInfo memory _initialInterest
    )
        ERC1155(string.concat("https://storage.amet.finance/7001/contracts", Strings.toHexString(address(this)), ".json"))
    {
        _bondRoles = _initialBondRoles;
        _bondInfo = _initialBondInfo;
        _bondLifecycle = _initialBondLifecycle;
        _feeInfo = _initialFeeInfo;
        _investment = _initialInvestment;
        _interest = _initialInterest;
    }

    /// @dev Before calling this function, the msg.sender should update the allowance of interest token for the bond contract
    /// @param count - count of the bonds that will be purchased
    function purchase(uint256 count) external {
        uint256 totalAmount = count * _investment.amount;
        _investment.token.safeTransferFrom(msg.sender, address(this), totalAmount);

        _mint(msg.sender, _bondInfo.uniqueBondIndex, count, "");
        _bondPurchaseBlocks[_bondInfo.uniqueBondIndex] = block.number;
        _bondInfo.uniqueBondIndex += 1;

        uint256 vaultFee = totalAmount - ((totalAmount * _feeInfo.vaultPurchaseFeePercentage) / 1000);
        uint256 investmentAmountToAdd = totalAmount - vaultFee;

        _investment.token.safeTransfer(_bondRoles.vault, vaultFee);

        if (_bondRoles.referrer != address(0)) {
            uint256 referralFee = totalAmount - ((totalAmount * _feeInfo.referrerPurchaseFeePercentage) / 1000);

            _referralCompletionBonus += referralFee;
            investmentAmountToAdd -= referralFee;
        }

        _investment.balance += investmentAmountToAdd;
    }

    /// @dev The function will redeem the bonds and transfer interest tokens to the msg.sender
    /// @param bondIndexes - array of the bond Indexes
    /// @param redemptionCount  - the count of the bonds that will be redeemed
    function redeem(uint40[] calldata bondIndexes, uint256 redemptionCount) external {
        uint256 amountToBePaid = redemptionCount * _interest.amount;
        if (_interest.balance < amountToBePaid) {
            revert OperationFailed(OperationCodes.InsufficientLiquidity);
        }

        for (uint40 i; i < bondIndexes.length; i++) {
            uint40 bondIndex = bondIndexes[i];
            if (_bondPurchaseBlocks[bondIndex] + _bondInfo.maturityThreshold < block.number) {
                revert OperationFailed(OperationCodes.RedemptionBeforeMaturity);
            }

            uint256 balanceByIndex = balanceOf(msg.sender, bondIndex);

            uint256 burnCount = balanceByIndex >= redemptionCount ? redemptionCount : balanceByIndex;
            _burn(msg.sender, bondIndex, redemptionCount);
            redemptionCount -= burnCount;
            if (redemptionCount == 0) break;
        }

        if (redemptionCount != 0) {
            revert OperationFailed(OperationCodes.InvalidAccess);
        }
        _interest.token.safeTransfer(msg.sender, amountToBePaid);
    }

    /// @dev Warning: Use this function only when you understand how it works
    /// @param bondIndexes -
    /// @param redemptionCount -
    function capitulationRedeem(uint40[] calldata bondIndexes, uint256 redemptionCount) external {
        uint256 toBePaid;

        for (uint40 i; i < bondIndexes.length; i++) {
            uint40 bondIndex = bondIndexes[i];

            uint256 blocksPassed = block.number - _bondPurchaseBlocks[bondIndex];
            uint256 balanceByIndex = balanceOf(msg.sender, bondIndex);

            uint256 burnCount = balanceByIndex >= redemptionCount ? redemptionCount : balanceByIndex;
            _burn(msg.sender, bondIndex, burnCount);
            redemptionCount -= burnCount;

            uint256 singleBondAmount = ((blocksPassed * _interest.amount)) / _bondInfo.maturityThreshold;
            toBePaid += (burnCount * (singleBondAmount - ((singleBondAmount * _bondInfo.earlyRedemptionFee) / 1000)));

            if (redemptionCount == 0) break;
        }

        _interest.token.safeTransfer(msg.sender, toBePaid);
    }

    // =========== Only Vault functions ===========

    /// @dev updates the vault address
    /// @param newVault - address
    function updateVaultAddress(address newVault) external onlyVaultOwner validAddress(newVault) {
        _bondRoles.vault = newVault;
    }

    function decreasePurchaseFeePercentage(uint8 newPurchaseFeePercentage) external onlyVaultOwner {
        if (_feeInfo.vaultPurchaseFeePercentage < newPurchaseFeePercentage) {
            revert OperationFailed(OperationCodes.InvalidAction);
        }
        _feeInfo.vaultPurchaseFeePercentage = newPurchaseFeePercentage;
    }

    function changeBaseURI(string calldata uri) external onlyVaultOwner {
        _setURI(uri);
    }

    // ===========================================

    // Only Issuer functions

    function settleContract() external onlyIssuer {
        if (((_bondInfo.total - _bondInfo.redeemed) * _interest.amount) > _interest.balance) {
            revert OperationFailed(OperationCodes.InsufficientLiquidity);
        }

        _bondInfo.isSettled = true;
        _investment.token.safeTransfer(_bondRoles.referrer, _referralCompletionBonus);
    }

    // function depositInterestTokens(uint256 amount) external onlyIssuer {
    //     bool depositStatus = IERC20(_interestToken).transferFrom(
    //         msg.sender,
    //         address(this),
    //         amount
    //     );
    //     require(depositStatus);
    //     _interestTokenBalance += amount;
    // }

    // function withdrawExcessInterest(address toAddress) external onlyIssuer {
    //     uint256 requiredAmountForTotalRedemption = (_total - _redeemed) *
    //         _interestTokenAmount;
    //     require(requiredAmountForTotalRedemption >= _interestTokenBalance);

    //     IERC20(_interestToken).transfer(
    //         toAddress,
    //         _interestTokenBalance - requiredAmountForTotalRedemption
    //     );
    // }

    // function withdrawInvestmentTokens(address toAddress, uint256 amount) external onlyIssuer {
    //     bool withdrawStatus = IERC20(_investmentToken).transferFrom(
    //         address(this),
    //         toAddress,
    //         amount
    //     );
    //     require(withdrawStatus);
    //     _investmentTokenBalance -= amount;
    // }

    // function decreaseMaturityThreshold(uint40 newMaturityThreshold) external onlyIssuer {
    //     require(newMaturityThreshold < _maturityThreshold);
    //     _maturityThreshold = newMaturityThreshold;
    // }

    // function updateIssuerAddress(address newIssuer) external onlyIssuer {
    //     _issuer = newIssuer;
    // }

    // function expandBondSupply(uint40 count) external onlyIssuer {
    //     _total += count;
    // }

    // function burnUnsoldBonds(uint40 count) external onlyIssuer {
    //     uint40 updatedTotal = _total - count;

    //     require(updatedTotal >= _purchased);
    //     _total = updatedTotal;
    // }

    // // ~~~~~ View only functions ~~~~~

    // function bondRoles() external view returns (CoreTypes.BondRoles memory) {
    //     return _bondRoles;
    // }

    // function bondInfo() external view returns (CoreTypes.BondInfo memory) {
    //     return _bondInfo;
    // }

    // function bondLifecycle() external view returns (CoreTypes.BondLifecycle memory) {
    //     return _bondLifecycle;
    // }

    // function feeInfo() external view returns (CoreTypes.FeeInfo memory) {
    //     return _feeInfo;
    // }

    // function investment() external view returns (CoreTypes.TokenInfo memory) {
    //     return _investment;
    // }

    // function interest() external view returns (CoreTypes.TokenInfo memory) {
    //     return _interest;
    // }

    // function referralCompletionBonus() external view returns (uint256) {
    //     return _referralCompletionBonus;
    // }

    function bondPurchaseBlocks(uint40[] calldata tokenIds) external view returns (uint256[] memory) {
        uint256[] memory purchasedBlocks = new uint256[](tokenIds.length);

        for (uint256 i; i < tokenIds.length; i++) {
            purchasedBlocks[i] = _bondPurchaseBlocks[tokenIds[i]];
        }

        return purchasedBlocks;
    }

    function getContractSummary()
        external
        view
        returns (
            CoreTypes.BondRoles memory,
            CoreTypes.BondInfo memory,
            CoreTypes.BondLifecycle memory,
            CoreTypes.FeeInfo memory,
            CoreTypes.TokenInfo memory,
            CoreTypes.TokenInfo memory,
            uint256
        )
    {
        return (_bondRoles, _bondInfo, _bondLifecycle, _feeInfo, _investment, _interest, _referralCompletionBonus);
    }
}
