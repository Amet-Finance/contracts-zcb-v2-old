// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {CoreTypes} from "./base/CoreTypes.sol";
import {ZeroCouponBonds} from "./ZeroCouponBonds.sol";

contract ZeroCouponBondsIssuer is Ownable {
    enum FeeTypes {
        Issuance,
        EarlyRedemption,
        VaultPurchase,
        ReferrerPurchase
    }

    event Issue(address indexed contractAddress);
    event FeeChanged(FeeTypes feeType, uint256 oldFee, uint256 newFee);

    error TransferFailed();
    error MissingFee();
    error ContractPaused();

    uint256 private _issuanceFee; // 1e18(1 ether)
    uint8 private _earlyRedemptionFeePercentage = 25; // fixed here, will update accordingly
    uint8 private _vaultPurchaseFeePercentage; // 50 for 5%
    uint8 private _referrerPurchaseFeePercentage; // 20 for 2%
    bool private _isPaused; // false

    modifier notPaused() {
        if (_isPaused) revert ContractPaused();
        _;
    }

    constructor(
        uint256 _initialIssuanceFee,
        uint8 _initialVaultPurchaseFeePercentage,
        uint8 _initialReferrerPurchaseFeePercentage
    ) Ownable(msg.sender) {
        _issuanceFee = _initialIssuanceFee;
        _vaultPurchaseFeePercentage = _initialVaultPurchaseFeePercentage;
        _referrerPurchaseFeePercentage = _initialReferrerPurchaseFeePercentage;
    }

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
    ) external payable notPaused {
        if (msg.value != _issuanceFee) revert MissingFee();
        (bool success,) = owner().call{value: _issuanceFee}("");
        if (!success) revert TransferFailed();

        bool referrerExists = address(referrer) != address(0);
        uint8 vaultPurchaseFeePercentageUpdated = referrerExists ? _vaultPurchaseFeePercentage - _referrerPurchaseFeePercentage : _vaultPurchaseFeePercentage;

        ZeroCouponBonds bondContract = new ZeroCouponBonds({
            _initialBondRoles: CoreTypes.BondRoles(msg.sender, referrer, owner()),
            _initialBondInfo: CoreTypes.BondInfo(total, 0, 0, 0, maturityThreshold, false, _earlyRedemptionFeePercentage),
            _initialBondLifecycle: CoreTypes.BondLifecycle(block.number, startBlock, endBlock),
            _initialFeeInfo: CoreTypes.FeeInfo(vaultPurchaseFeePercentageUpdated, _referrerPurchaseFeePercentage),
            _initialInvestment: CoreTypes.TokenInfo(0, IERC20(investmentToken), investmentTokenAmount),
            _initialInterest: CoreTypes.TokenInfo(0, IERC20(interestToken), interestTokenAmount)
        });

        emit Issue(address(bondContract));
    }

    function changeIssuanceFee(uint256 fee) external onlyOwner {
        emit FeeChanged(FeeTypes.Issuance, _issuanceFee, fee);
        _issuanceFee = fee;
    }

    function changeEarlyRedemptionFeePercentage(uint8 fee) external onlyOwner {
        emit FeeChanged(FeeTypes.EarlyRedemption, _earlyRedemptionFeePercentage, fee);
        _earlyRedemptionFeePercentage = fee;
    }

    function changeVaultPurchaseFeePercentage(uint8 fee) external onlyOwner {
        emit FeeChanged(FeeTypes.VaultPurchase, _vaultPurchaseFeePercentage, fee);
        _vaultPurchaseFeePercentage = fee;
    }

    function changeReferrerPurchaseFeePercentage(uint8 fee) external onlyOwner {
        emit FeeChanged(FeeTypes.ReferrerPurchase, _referrerPurchaseFeePercentage, fee);
        _referrerPurchaseFeePercentage = fee;
    }
}
