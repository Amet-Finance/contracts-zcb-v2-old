// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

library CoreTypes {    
    
    struct BondInfo {
        uint40 total;
        uint40 purchased;
        uint40 redeemed;
        uint40 uniqueBondIndex;
        uint40 maturityThreshold;
        bool isSettled; // when this is done no other thing can be done, burn/issue and etc...
        bool isPaused; // when this is done no other thing can be done, burn/issue and etc...
        uint8 purchaseFeePercentage; // purchase fee percentage
        uint8 earlyRedemptionFeePercentage; // fee percentage to deduct when redeemed early
    }
}