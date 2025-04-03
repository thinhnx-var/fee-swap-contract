// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract HelloInterface {
    function sayHello() public pure returns (string memory) {
        return "hello";
    }
}