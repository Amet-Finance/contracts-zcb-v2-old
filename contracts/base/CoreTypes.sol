// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

library CoreTypes {

    error OnlyIssuer();
    error OnlyVaultOwner();

    struct BondRoles {
        address issuer;
        address referrer;
        address vault;
    }
    
    struct BondInfo {
        uint40 total;
        uint40 purchased;
        uint40 redeemed;
        uint40 uniqueBondIndex;
        uint40 maturityThreshold;
        bool isSettled; // when this is done no other thing can be done, burn/issue and etc...
        uint8 earlyRedemptionFee; // fee percentage to deduct when redeemed early
    }

    struct BondLifecycle {
        uint256 issuanceBlock;
        uint256 startBlock;
        uint256 endBlock;
    }

    struct FeeInfo {
        uint8 vaultPurchaseFeePercentage;
        uint8 referrerPurchaseFeePercentage;
    }

    struct TokenInfo {
        uint256 balance;
        IERC20 token;
        uint256 amount;
    }

}