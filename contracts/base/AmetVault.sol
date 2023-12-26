// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {CoreTypes} from "../libraries/CoreTypes.sol";
import {IZeroCouponBondsV2} from "../interfaces/IZeroCouponBonds.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract AmetVault is Ownable {
    using SafeERC20 for IERC20;
    
    address private _issuerContract;
    uint8 private _referrerPurchaseFeePercentage;

    modifier onlyIssuerContract() {
        require(msg.sender == _issuerContract);
        _;
    }

    mapping(address wallet => mapping(address bond => bool isRepayed)) private _repaymentStatuses;
    mapping(address => address) private _referrerByContract;

    constructor(address _initialIssuerContract) Ownable(msg.sender) {
        _issuerContract = _initialIssuerContract;
    }

    // Referral logic
    function setReferrer(address contractAddress, address referrer) external onlyIssuerContract {
        _referrerByContract[contractAddress] = referrer;
    }

    function claimReferralRewards(address bondAddress) external {
        address referrer = _referrerByContract[bondAddress];
        require(referrer != address(0));
        require(_repaymentStatuses[bondAddress][referrer] == false);


        IZeroCouponBondsV2 bondContract = IZeroCouponBondsV2(bondAddress);
        CoreTypes.BondInfo memory bondInfo = bondContract.bondInfo();


        if(bondInfo.purchased == bondInfo.total && bondInfo.isSettled){      
            uint256 amount = ((bondInfo.purchased * bondContract.interestAmount()) * _referrerPurchaseFeePercentage) / 1000;
            IERC20(bondContract.interestToken()).safeTransfer(referrer, amount);
            _repaymentStatuses[bondAddress][referrer] = true;
        }
    }

    function withdraw(address token,address toAddress, uint256 amount) external onlyOwner {
        IERC20(token).safeTransfer(toAddress, amount);
    }


    function changeReferrerPurchaseFeePercentage(uint8 fee) external onlyOwner {
        // emit FeeChanged(FeeTypes.ReferrerPurchase, _referrerPurchaseFeePercentage, fee);
        _referrerPurchaseFeePercentage = fee;
    }
}