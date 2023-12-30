// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {CoreTypes} from "../libraries/CoreTypes.sol";

interface IZeroCouponBondsV2 {

    function isSettledAndFullyPurchased() external view returns (bool);

    function interestToken() external view returns (address);
    function interestAmount() external view returns(uint256);
    
}


