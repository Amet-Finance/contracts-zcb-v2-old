// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {CoreTypes} from "../libraries/CoreTypes.sol";
import {IZeroCouponBondsV2} from "../interfaces/IZeroCouponBonds.sol";
import {IZeroCouponBondsIssuerV2} from "../interfaces/IZeroCouponBondsIssuer.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract AmetVault is Ownable {
    using SafeERC20 for IERC20;

    struct ReferrerInfo {
        uint40 count;
        bool isRepaid;
    }

    event ReferralPurchaseFeeChanged(uint8 fee);
    event ReferralRecord(address bondContractAddress, address referrer, uint40 amount);

    address public issuerContract;
    uint8 private referrerPurchaseFeePercentage;

    mapping(address bondContract => mapping(address referrer => ReferrerInfo)) public referrers;

    modifier onlyAuthorizedContracts(address bondContractAddress) {
        require(IZeroCouponBondsIssuerV2(issuerContract).isVaildContract(bondContractAddress), "Contract is not valid");
        _;
    }

    receive() external payable {}

    constructor(address _initialIssuerContract) Ownable(msg.sender) {
        issuerContract = _initialIssuerContract;
    }

    function recordReferralPurchase(address referrer, uint40 count) external onlyAuthorizedContracts(msg.sender) {
        emit ReferralRecord(msg.sender, referrer, count);
        referrers[msg.sender][referrer].count += count;
    }

    function claimReferralRewards(address bondContractAddress) external onlyAuthorizedContracts(bondContractAddress) {
        ReferrerInfo storage referrer = referrers[bondContractAddress][msg.sender];
        require(!referrer.isRepaid && referrer.count > 0);

        IZeroCouponBondsV2 bondContract = IZeroCouponBondsV2(bondContractAddress);

        if (bondContract.isSettledAndFullyPurchased()) {
            referrer.isRepaid = true;
            IERC20(bondContract.interestToken()).safeTransfer(
                msg.sender, (((referrer.count * bondContract.interestAmount()) * referrerPurchaseFeePercentage) / 1000)
            );
        }
    }

    
    ///////////////////////////////////
    //     Only owner functions     //
    /////////////////////////////////

    function withdrawERC20(address token, address toAddress, uint256 amount) external onlyOwner {
        IERC20(token).safeTransfer(toAddress, amount);
    }

    function changeReferrerPurchaseFeePercentage(uint8 fee) external onlyOwner {
        emit ReferralPurchaseFeeChanged(fee);
        referrerPurchaseFeePercentage = fee;
    }
}
