// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Token is ERC20 {
    constructor() ERC20("Tether USD", "USDT"){
        _mint(msg.sender, 5000000000000 * 1e18);
    }
}
