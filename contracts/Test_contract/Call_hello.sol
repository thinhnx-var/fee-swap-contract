// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IHello {
    function sayHello() external pure returns (string memory);
}

contract CallerContract {
    address public helloContractAddress;
    string public lastHelloMessage;

    constructor(address _helloContractAddress) {
        helloContractAddress = _helloContractAddress;
    }

    function callHello() public {
        IHello helloContract = IHello(helloContractAddress);
        try helloContract.sayHello() returns (string memory helloMessage) {
            lastHelloMessage = helloMessage;
        } catch {
            lastHelloMessage = "Error calling sayHello"; // Handle errors
        }
    }

    function getLastHello() public view returns (string memory) {
        return lastHelloMessage;
    }
}