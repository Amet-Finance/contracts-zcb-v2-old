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

import {CoreTypes} from "./libraries/CoreTypes.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

contract ZeroCouponBonds is ERC1155 {
    using SafeERC20 for IERC20;

    enum OperationCodes {
        InsufficientLiquidity,
        RedemptionBeforeMaturity,
        InvalidAccess,
        ContractAlreadySettled,
        InvalidAddress,
        InvalidAction
    }

    error OperationFailed(OperationCodes code);

    address public issuer;
    address public immutable vault;
    
    CoreTypes.BondInfo public bondInfo;

    address public immutable investmentToken;
    uint256 public immutable investmentAmount;

    address public immutable interestToken;
    uint256 public immutable interestAmount;

    /// @dev tokenId => blockNumber: the block when the bond(s) was(were) purchased
    mapping(uint40 => uint256) public _bondPurchaseBlocks;

    modifier onlyIssuer() {
        if (msg.sender != issuer) revert OperationFailed(OperationCodes.InvalidAccess);
        _;
    }

    modifier validAddress(address _addr) {
        if (_addr == address(0)) revert OperationFailed(OperationCodes.InvalidAddress);
        _;
    }

    modifier notSettled() {
        if (bondInfo.isSettled) revert OperationFailed(OperationCodes.ContractAlreadySettled);
        _;
    }
    

    constructor(
        address _initialIssuer,
        address _initialVault,

        CoreTypes.BondInfo memory _initialBondInfo,

        address _initialInvestmentToken,
        uint256 _initialInvestmentAmount,
        address _initialInterestToken,
        uint256 _initialInterestAmount
    )
        ERC1155(string.concat("https://storage.amet.finance/7001/contracts", Strings.toHexString(address(this)), ".json"))
    {
        issuer = _initialIssuer;
        vault = _initialVault;
        
        bondInfo = _initialBondInfo;

        investmentToken = _initialInvestmentToken;
        investmentAmount =  _initialInvestmentAmount;

        interestToken = _initialInterestToken;
        interestAmount = _initialInterestAmount;
    }

    /// @dev Before calling this function, the msg.sender should update the allowance of interest token for the bond contract
    /// @param count - count of the bonds that will be purchased
    function purchase(uint256 count) external {
        if (bondInfo.isPaused) revert OperationFailed(OperationCodes.InvalidAction);
        
        IERC20 investment = IERC20(investmentToken);
        
        uint256 totalAmount = count * investmentAmount;
        
        _mint(msg.sender, bondInfo.uniqueBondIndex, count, "");
        _bondPurchaseBlocks[bondInfo.uniqueBondIndex] = block.number;
        bondInfo.uniqueBondIndex += 1;

        uint256 purchaseFee = (totalAmount * bondInfo.purchaseFeePercentage) / 1000;

        investment.safeTransferFrom(msg.sender, vault, purchaseFee);
        investment.safeTransferFrom(msg.sender, issuer, totalAmount - purchaseFee);
    }

    /// @dev The function will redeem the bonds and transfer interest tokens to the msg.sender
    /// @param bondIndexes - array of the bond Indexes
    /// @param redemptionCount  - the count of the bonds that will be redeemed
    function redeem(uint40[] calldata bondIndexes, uint256 redemptionCount, bool isCapitulation) external {
        uint256 amountToBePaid = redemptionCount * interestAmount;
        IERC20 interest = IERC20(interestToken);

        if (interest.balanceOf(address(this)) < amountToBePaid && isCapitulation == false) {
            revert OperationFailed(OperationCodes.InsufficientLiquidity);
        }

        for (uint40 i; i < bondIndexes.length; i++) {
            uint40 bondIndex = bondIndexes[i];
            if (_bondPurchaseBlocks[bondIndex] + bondInfo.maturityThreshold < block.number && isCapitulation == false) {
                revert OperationFailed(OperationCodes.RedemptionBeforeMaturity);
            }

            uint256 balanceByIndex = balanceOf(msg.sender, bondIndex);

            uint256 burnCount = balanceByIndex >= redemptionCount ? redemptionCount : balanceByIndex;
            _burn(msg.sender, bondIndex, redemptionCount);
            redemptionCount -= burnCount;

            if (isCapitulation) {
                uint256 blocksPassed = block.number - _bondPurchaseBlocks[bondIndex];
                
                uint256 amountToBePaidOG = burnCount * interestAmount;
                
                uint256 bondsAmountForCapitulation = ((burnCount * blocksPassed * interestAmount)) / bondInfo.maturityThreshold;
                uint256 feeDeducted = bondsAmountForCapitulation - ((bondsAmountForCapitulation * bondInfo.earlyRedemptionFeePercentage) /1000);
                // 
                amountToBePaid -= (amountToBePaidOG - feeDeducted);
            }

            if (redemptionCount == 0) break;
        }

        if (redemptionCount != 0) {
            revert OperationFailed(OperationCodes.InvalidAction);
        }

        interest.safeTransfer(msg.sender, amountToBePaid);
    }
    // ===========================================

    // Only Issuer functions

    /// @dev When settling contract it means that no other bond can be issued/burned and the interest amount should be equal to (total - redeemed) * interestAmount
    /// isSettled adds the lvl of security. Bond purchasers can be sure that no other bond can be issued and the bond is totally redeemable
    function settleContract() external onlyIssuer {
        IERC20 interest = IERC20(interestToken);
        uint256 totalInterestRequired = (bondInfo.total - bondInfo.redeemed) * interestAmount;

        if (totalInterestRequired > interest.balanceOf(address(this))) {
            revert OperationFailed(OperationCodes.InsufficientLiquidity);
        }

        bondInfo.isSettled = true;
    }

    /// @dev The function for depositing interest tokens
    /// @param amount - the amount of interst tokens that need to be deposited
    function depositInterestTokens(uint256 amount) external {
        IERC20(interestToken).safeTransferFrom(msg.sender, address(this), amount);
    }

    function withdrawExcessInterest(address toAddress) external onlyIssuer {
        uint256 requiredAmountForTotalRedemption = (bondInfo.total - bondInfo.redeemed) * interestAmount;
        IERC20 interest = IERC20(interestToken);


        uint256 interestBalance = interest.balanceOf(address(this));
        if (interestBalance <= requiredAmountForTotalRedemption) {
            revert OperationFailed(OperationCodes.InsufficientLiquidity);
        }

        interest.safeTransfer(toAddress, interestBalance - requiredAmountForTotalRedemption);
    }

    function decreaseMaturityThreshold(uint40 newMaturityThreshold) external onlyIssuer {
        if (newMaturityThreshold >= bondInfo.maturityThreshold) revert OperationFailed(OperationCodes.InvalidAction);
        bondInfo.maturityThreshold = newMaturityThreshold;
    }

    function updateIssuerAddress(address newIssuer) external onlyIssuer validAddress(newIssuer) {
        issuer = newIssuer;
    }

    /// @dev updates the bond total supply, checks if you put more then was purchased
    /// @param newTotal - new total
    function updateBondSupply(uint40 newTotal) external onlyIssuer notSettled {
        if(bondInfo.purchased > newTotal ) revert OperationFailed(OperationCodes.InvalidAction);
        bondInfo.total = newTotal;
    }
}
