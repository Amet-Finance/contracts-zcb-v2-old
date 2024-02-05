// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface IZeroCouponBondsIssuer {
    function issuedContracts(address bondContract) external view returns (bool);
    function vault() external view returns (address);
}
