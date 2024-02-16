// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;
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
 *
 * The bond contract is created in the issueBondContract(ZeroCouponBondsIssuer.sol). The lifecycle of the bond is as follows:
 *      purchase ===> maturityPeriod ===> redeem
 *
 * So you purchase bonds, wait until it gets mature, and redeem.
 *
 * Optional:
 * - Change chainId in the _uri
 */

import {IZeroCouponBondsIssuer} from "./interfaces/IZeroCouponBondsIssuer.sol";
import {IAmetVault} from "./interfaces/IAmetVault.sol";
import {CoreTypes} from "./libraries/CoreTypes.sol";

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract ZeroCouponBonds is ERC1155, Ownable {
    using SafeERC20 for IERC20;

    enum OperationCodes {
        InsufficientInterest,
        RedemptionBeforeMaturity,
        InvalidAction,
        RenouncingOwnership
    }

    error OperationFailed(OperationCodes code);

    event SettleContract();
    event UpdateBondSupply(uint40 total);
    event DecreaseMaturityPeriod(uint40 maturityPeriod);

    string private constant BASE_URI = "https://storage.amet.finance/contracts";
    address public immutable issuerContract;

    CoreTypes.BondInfo public bondInfo;

    address public immutable investmentToken;
    uint256 public immutable investmentAmount;

    address public immutable interestToken;
    uint256 public immutable interestAmount;

    mapping(uint40 tokenId => uint256 blockNumber) public bondPurchaseBlocks;

    constructor(
        address _initialIssuer,
        CoreTypes.BondInfo memory _initialBondInfo,
        address _initialInvestmentToken,
        uint256 _initialInvestmentAmount,
        address _initialInterestToken,
        uint256 _initialInterestAmount
    ) ERC1155(string.concat(BASE_URI, Strings.toHexString(address(this)), "_8001.json")) Ownable(_initialIssuer) {
        issuerContract = msg.sender;

        bondInfo = _initialBondInfo;

        investmentToken = _initialInvestmentToken;
        investmentAmount = _initialInvestmentAmount;

        interestToken = _initialInterestToken;
        interestAmount = _initialInterestAmount;
    }

    /// @dev Before calling this function, the msg.sender should update the allowance of interest token for the bond contract
    /// @param count - count of the bonds that will be purchased
    function purchase(uint40 count, address referrer) external {
        CoreTypes.BondInfo storage bondInfoTmp = bondInfo;
        address vaultAddress = IZeroCouponBondsIssuer(issuerContract).vault();

        if (bondInfoTmp.purchased + count > bondInfoTmp.total) revert OperationFailed(OperationCodes.InvalidAction);

        IERC20 investment = IERC20(investmentToken);
        uint256 totalAmount = count * investmentAmount;

        uint256 purchaseFee = (totalAmount * bondInfoTmp.purchaseFeePercentage) / 1000;

        investment.safeTransferFrom(msg.sender, vaultAddress, purchaseFee);
        investment.safeTransferFrom(msg.sender, owner(), totalAmount - purchaseFee);

        bondInfoTmp.purchased += count;
        bondPurchaseBlocks[bondInfoTmp.uniqueBondIndex] = block.number;

        _mint(msg.sender, bondInfoTmp.uniqueBondIndex++, count, "");

        if (referrer != address(0) && referrer != msg.sender) IAmetVault(vaultAddress).recordReferralPurchase(referrer, count);
    }

    /// @dev The function will redeem the bonds and transfer interest tokens to the msg.sender
    /// @param bondIndexes - array of the bond Indexes
    /// @param redemptionCount  - the count of the bonds that will be redeemed
    /// @param isCapitulation  - when set to true will execute capitulation redeem logic
    function redeem(uint40[] calldata bondIndexes, uint40 redemptionCount, bool isCapitulation) external {
        uint256 interestAmountToBePaid = interestAmount;
        CoreTypes.BondInfo storage bondInfoTmp = bondInfo;

        uint256 amountToBePaid = redemptionCount * interestAmountToBePaid;
        IERC20 interest = IERC20(interestToken);

        bondInfoTmp.redeemed += redemptionCount;

        if (amountToBePaid > interest.balanceOf(address(this)) && !isCapitulation) {
            revert OperationFailed(OperationCodes.InsufficientInterest);
        }

        uint256 bondIndexesLength = bondIndexes.length;

        for (uint40 i; i < bondIndexesLength;) {
            uint40 bondIndex = bondIndexes[i];
            uint256 purchasedBlock = bondPurchaseBlocks[bondIndex];
            bool isMature = purchasedBlock + bondInfoTmp.maturityPeriod <= block.number;

            if (!isMature && !isCapitulation) {
                revert OperationFailed(OperationCodes.RedemptionBeforeMaturity);
            }

            uint40 balanceByIndex = uint40(balanceOf(msg.sender, bondIndex));
            uint40 burnCount = balanceByIndex >= redemptionCount ? redemptionCount : balanceByIndex;

            _burn(msg.sender, bondIndex, redemptionCount);
            redemptionCount -= burnCount;

            if (isCapitulation && !isMature) {
                uint256 bondsAmountForCapitulation =
                    ((burnCount * (block.number - purchasedBlock) * interestAmountToBePaid)) / bondInfoTmp.maturityPeriod;
                uint256 feeDeducted = bondsAmountForCapitulation
                    - ((bondsAmountForCapitulation * bondInfoTmp.earlyRedemptionFeePercentage) / 1000);

                amountToBePaid -= ((burnCount * interestAmountToBePaid) - feeDeducted);
            }

            if (redemptionCount == 0) break;
            unchecked {
                i += 1;
            }
        }

        if (redemptionCount != 0) {
            revert OperationFailed(OperationCodes.InvalidAction);
        }

        interest.safeTransfer(msg.sender, amountToBePaid);
    }

    ////////////////////////////////////
    //      Only Owner functions     //
    //////////////////////////////////

    /// @dev When settling contract it means that no other bond can be issued/burned and the interest amount should be equal to (total - redeemed) * interestAmount
    /// isSettled adds the lvl of security. Bond purchasers can be sure that no other bond can be issued and the bond is totally redeemable
    function settleContract() external onlyOwner {
        CoreTypes.BondInfo storage bondInfoLocal = bondInfo;
        IERC20 interest = IERC20(interestToken);
        uint256 totalInterestRequired = (bondInfoLocal.total - bondInfoLocal.redeemed) * interestAmount;

        if (totalInterestRequired > interest.balanceOf(address(this))) {
            revert OperationFailed(OperationCodes.InsufficientInterest);
        }

        bondInfoLocal.isSettled = true;
        emit SettleContract();
    }

    /// @dev For withdrawing the excess interest that was accidentally deposited to the contract
    /// @param toAddress - the address to send the excess interest
    function withdrawExcessInterest(address toAddress) external onlyOwner {
        CoreTypes.notZeroAddress(toAddress);
        CoreTypes.BondInfo memory bondInfoLocal = bondInfo;
        uint256 requiredAmountForTotalRedemption = (bondInfoLocal.total - bondInfoLocal.redeemed) * interestAmount;
        IERC20 interest = IERC20(interestToken);

        uint256 interestBalance = interest.balanceOf(address(this));
        if (interestBalance <= requiredAmountForTotalRedemption) {
            revert OperationFailed(OperationCodes.InsufficientInterest);
        }

        interest.safeTransfer(toAddress, interestBalance - requiredAmountForTotalRedemption);
    }

    /// @dev Decreses maturity treshold of the bond
    /// @param newMaturityPeriod - new decreased maturity threshold
    function decreaseMaturityPeriod(uint40 newMaturityPeriod) external onlyOwner {
        CoreTypes.BondInfo storage bondInfoLocal = bondInfo;
        if (newMaturityPeriod >= bondInfoLocal.maturityPeriod) {
            revert OperationFailed(OperationCodes.InvalidAction);
        }
        bondInfoLocal.maturityPeriod = newMaturityPeriod;
        emit DecreaseMaturityPeriod(newMaturityPeriod);
    }

    /// @dev updates the bond total supply, checks if you put more than was purchased
    /// if the bond is settled, you only can decrease the supply
    /// @param total - new total value
    function updateBondSupply(uint40 total) external onlyOwner {
        CoreTypes.BondInfo storage bondInfoLocal = bondInfo;
        if (bondInfoLocal.purchased > total || (bondInfoLocal.isSettled && total > bondInfoLocal.total)) {
            revert OperationFailed(OperationCodes.InvalidAction);
        }
        bondInfoLocal.total = total;
        emit UpdateBondSupply(total);
    }

    function renounceOwnership() public view override onlyOwner {
        revert OperationFailed(OperationCodes.RenouncingOwnership);
    }
}

