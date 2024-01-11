// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

library CoreTypes {

    error ZeroAddress();

    struct BondInfo {
        uint40 total;
        uint40 purchased;
        uint40 redeemed;
        uint40 uniqueBondIndex;
        uint40 maturityThreshold;
        bool isSettled; // when this is done no other thing can be done, burn/issue and etc...
        uint8 purchaseFeePercentage; // purchase fee percentage
        uint8 earlyRedemptionFeePercentage; // fee percentage to deduct when redeemed early
    }

    function notZeroAddress(address addr) internal pure {
        if(addr == address(0)) revert ZeroAddress();
    } 
}
