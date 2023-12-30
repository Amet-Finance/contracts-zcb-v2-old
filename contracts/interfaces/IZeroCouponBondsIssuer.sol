// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {CoreTypes} from "../libraries/CoreTypes.sol";

interface IZeroCouponBondsIssuerV2 {

    function issuedContracts(address bondContract) external view returns(bool);
    
}


