# Amet Finance
## Zero Coupon Bonds V2

### Overview
Amet Finance's ZCBv2 (Zero-Coupon Bonds Version 2) represents our latest advancement in blockchain-based financial instruments. These contracts leverage the power and flexibility of decentralized finance (DeFi) to offer innovative bond solutions.

### Contracts
[AmetVault.sol](contracts%2FAmetVault.sol): Contract for managing vault and referral rewards logic
[ZeroCouponBonds.sol](contracts%2FZeroCouponBonds.sol): Contract for core bond logic
[ZeroCouponBondsIssuer.sol](contracts%2FZeroCouponBondsIssuer.sol): Contract for issuing bond and managing high lvl variables(such as issuanceFee, purchaseFeePercentage and etc...)

### Interfaces
- [IAmetVault.sol](contracts%2Finterfaces%2FIAmetVault.sol): Vault Interface
- [IZeroCouponBonds.sol](contracts%2Finterfaces%2FIZeroCouponBonds.sol): ZCB Interface
- [IZeroCouponBondsIssuer.sol](contracts%2Finterfaces%2FIZeroCouponBondsIssuer.sol): ZCB Issuer Interface

### Libraries
- [CoreTypes.sol](contracts%2Flibraries%2FCoreTypes.sol): Core types for ZCB

### [Test Contracts](contracts%2Ftest-contracts)
[Token.t.sol](contracts%2Ftest-contracts%2FToken.t.sol): Token ERC20


### Features
- **Enhanced Gas Efficiency**: Utilizing the ERC1155 standard for bond representation, leading to reduced transaction costs.
- **Capitulation Redeem Logic**: Allows bondholders to redeem their bonds early under specific conditions.
- **Robust Referral System**: Integrates a sophisticated referral mechanism to incentivize and reward community participation.


### Testing
- Running Mocha tests
```shell
npm run test
```
- Running Slither
```shell
npm run test:contracts:slither
```

- Running Mythril
```shell
npm run test:contracts:mythril
```

