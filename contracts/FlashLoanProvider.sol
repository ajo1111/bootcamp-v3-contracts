// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Token} from "./Token.sol";

interface IFlashLoanReceiver {
    function receiveFlashloan(
        address token,
        uint256 amount,
        bytes memory data
    ) external;
}

// We don't want to deploy this contract. We only want
// our Exchange contract to inherit from it,
// thus we make it abstract.
abstract contract FlashLoanProvider {
    event FlashLoan(address token, uint256 amount, uint256 timestamp);

    function flashloan(
        address _token,
        uint256 _amount,
        bytes memory _data
    ) public {
        // Get our current token balance
        uint256 tokenBalanceBefore = Token(_token).balanceOf(address(this));

        // Require this contract to have sufficient funds to send
        require(
            tokenBalanceBefore > 0,
            "FlashLoanProvider: Insufficient funds to loan"
        );

        // Send funds to msg.sender
        require(
            Token(_token).transfer(msg.sender, _amount),
            "FlashLoanProvider: Transfer failed"
        );        

        // Call the receiveFlashLoan() on msg.sender
        IFlashLoanReceiver(msg.sender).receiveFlashloan(_token, _amount, _data);

        // get our token balance after
        uint256 tokenBalanceAfter = Token(_token).balanceOf(address(this));

        // Require this contract to have received back the funds
        require(
            tokenBalanceAfter >= tokenBalanceBefore,
            "FlashLoanProvider: Funds not received"
        );

        // Emit an Event
        emit FlashLoan(_token, _amount, block.timestamp);
    }
}
