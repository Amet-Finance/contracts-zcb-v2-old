// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
// 4. [Important]Add pause state for bonds contract, not only on the issuer contract, only AMET_VAULT can pause the contract
// 3. [Discuss]Add a referral system, the address can be put before issuing, and will need to be verified by the AMET_VAULT

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {CoreTypes} from "./base/CoreTypes.sol";
import {ZeroCouponBonds} from "./ZeroCouponBonds.sol";

contract ZeroCouponBondsIssuer is Ownable {
    event Issue(address indexed contractAddress);

    uint256 private _issuanceFee;
    uint8 private _earlyRedemptionFee = 25; // fixed here, will update accordingly
    uint8 private _vaultPurchaseFeePercentage;
    uint8 private _referrerPurchaseFeePercentage;

    constructor(
        uint256 _initialIssuanceFee,
        uint8 _initialVaultPurchaseFeePercentage,
        uint8 _initialReferrerPurchaseFeePercentage
    ) Ownable(msg.sender) {
        _issuanceFee = _initialIssuanceFee;
        _vaultPurchaseFeePercentage = _initialVaultPurchaseFeePercentage;
        _referrerPurchaseFeePercentage = _initialReferrerPurchaseFeePercentage;
    }

    // this function should take fee as well
    function issueBonds(
        address referrer,
        uint40 total,
        uint40 maturityThreshold,
        uint256 startBlock,
        uint256 endBlock,
        address investmentToken,
        uint256 investmentTokenAmount,
        address interestToken,
        uint256 interestTokenAmount
    ) external payable {
        ZeroCouponBonds bondContract = new ZeroCouponBonds({
            _initialBondRoles: CoreTypes.BondRoles(msg.sender, referrer, owner()),
            _initialBondInfo: CoreTypes.BondInfo(total, 0, 0, 0, maturityThreshold, false, _earlyRedemptionFee),
            _initialBondLifecycle: CoreTypes.BondLifecycle(block.number, startBlock, endBlock),
            _initialFeeInfo: CoreTypes.FeeInfo(_vaultPurchaseFeePercentage, _referrerPurchaseFeePercentage),
            _initialInvestment: CoreTypes.TokenInfo(0, IERC20(investmentToken), investmentTokenAmount),
            _initialInterest: CoreTypes.TokenInfo(0, IERC20(interestToken), interestTokenAmount)
        });

        emit Issue(address(bondContract));
    }
}
