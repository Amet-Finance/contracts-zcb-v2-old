// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IZeroCouponBonds} from "./interfaces/IZeroCouponBonds.sol";
import {IZeroCouponBondsIssuer} from "./interfaces/IZeroCouponBondsIssuer.sol";
import {CoreTypes} from "./libraries/CoreTypes.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IAmetVault} from "./interfaces/IAmetVault.sol";

contract AmetVault is Ownable, IAmetVault {
    using SafeERC20 for IERC20;

    struct ReferrerInfo {
        uint40 count;
        bool isRepaid;
    }

    enum FeeTypes {
        IssuanceFee,
        ReferralPurchase
    }

    event FeeChanged(FeeTypes, uint256 fee);
    event FeesWithdrawn(address toAddress, uint256 amount, bool isERC20);
    event ReferralRecord(address bondContractAddress, address referrer, uint40 amount);
    event ReferrerRewardClaimed(address referrer, uint256 amount);

    error BlacklistAddress();
    error WrongIssuanceFee();

    address public immutable issuerContract;
    uint256 public issuanceFee;
    uint8 private referrerPurchaseFeePercentage;

    mapping(address bondContract => mapping(address referrer => ReferrerInfo)) public referrers;
    mapping(address => uint8) public blakclistAddresses;

    modifier onlyAuthorizedContracts(address bondContractAddress) {
        require(IZeroCouponBondsIssuer(issuerContract).issuedContracts(bondContractAddress), "Contract is not valid");
        _;
    }

    receive() external payable {}

    constructor(address _initialIssuerContract, uint256 _initialIssuanceFee) Ownable(msg.sender) {
        issuerContract = _initialIssuerContract;
        issuanceFee = _initialIssuanceFee;
    }

    ///////////////////////////////////
    //        Fee Management        //
    /////////////////////////////////

    function depositInssuanceFee() external payable {
        if (msg.value != issuanceFee) revert WrongIssuanceFee();
    }

    /// @dev Changes the issuance fee(ETHER) for the upcoming bonds
    /// @param fee - new fee
    function changeIssuanceFee(uint256 fee) external onlyOwner {
        issuanceFee = fee;
        emit FeeChanged(FeeTypes.IssuanceFee, fee);
    }

    ///////////////////////////////////
    //        Referral logic        //
    /////////////////////////////////

    /// @dev This function blocks address for referral rewards
    /// @param referrer - Referrer address
    /// @param status - 0 for false, 1 for true
    function blockAddressForReferralRewards(address referrer, uint8 status) external onlyOwner {
        blakclistAddresses[referrer] = status;
    }

    /// @dev Records referral purchase for the bond contract
    /// @param referrer - address of the referrer
    /// @param count - count of the bonds that was purchased by the referral
    function recordReferralPurchase(address referrer, uint40 count) external onlyAuthorizedContracts(msg.sender) {
        if (blakclistAddresses[referrer] == 1) revert BlacklistAddress();
        referrers[msg.sender][referrer].count += count;
        emit ReferralRecord(msg.sender, referrer, count);
    }

    /// @dev After the bond contract is settled, referrers can claim their rewards
    /// @param bondContractAddress - the address of the bond contract
    function claimReferralRewards(address bondContractAddress) external onlyAuthorizedContracts(bondContractAddress) {
        ReferrerInfo storage referrer = referrers[bondContractAddress][msg.sender];
        require(!referrer.isRepaid && referrer.count != 0);

        IZeroCouponBonds bondContract = IZeroCouponBonds(bondContractAddress);

        if (isSettledAndFullyPurchased(bondContract)) {
            referrer.isRepaid = true;
            uint256 rewardAmount =
                (((referrer.count * bondContract.interestAmount()) * referrerPurchaseFeePercentage) / 1000);
            IERC20(bondContract.interestToken()).safeTransfer(msg.sender, rewardAmount);
            emit ReferrerRewardClaimed(msg.sender, rewardAmount);
        }
    }

    ///////////////////////////////////
    //     Only owner functions     //
    /////////////////////////////////

    /// @dev Withdraws the Ether(issuance fees)
    /// @param toAddress - address to transfer token
    /// @param amount - amount to transfer
    function withdrawETH(address toAddress, uint256 amount) external onlyOwner {
        (bool success,) = toAddress.call{value: amount}("");
        require(success);
        emit FeesWithdrawn(toAddress, amount, false);
    }

    /// @dev Withdraws the ERC20 token(purchase fees)
    /// @param toAddress - address to transfer token
    /// @param amount - amount to transfer
    function withdrawERC20(address token, address toAddress, uint256 amount) external onlyOwner {
        IERC20(token).safeTransfer(toAddress, amount);
        emit FeesWithdrawn(toAddress, amount, true);
    }

    /// @dev Changes the Referrer Purchase Fee percentage
    /// @param fee - new fee value
    function changeReferrerPurchaseFeePercentage(uint8 fee) external onlyOwner {
        referrerPurchaseFeePercentage = fee;
        emit FeeChanged(FeeTypes.ReferralPurchase, fee);
    }

    ////////////////////////////////////
    //       View only functions     //
    //////////////////////////////////

    /// @dev - returns true if contract can not issue more bonds && fully repaid the purchasers && totally purchased
    function isSettledAndFullyPurchased(IZeroCouponBonds bondContract) internal view returns (bool) {
        CoreTypes.BondInfo memory bondInfoLocal = bondContract.bondInfo();
        return bondInfoLocal.isSettled && bondInfoLocal.total == bondInfoLocal.purchased;
    }
}
