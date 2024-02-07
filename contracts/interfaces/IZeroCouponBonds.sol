// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {CoreTypes} from "../libraries/CoreTypes.sol";

interface IZeroCouponBonds {
    function bondInfo() external view returns(CoreTypes.BondInfo memory);
    function investmentToken() external view returns (address);
    function investmentAmount() external view returns (uint256);
}
