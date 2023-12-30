// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;


interface IAmetVault {
    
    function recordReferralPurchase(address referrer, uint40 amount) external;
}


