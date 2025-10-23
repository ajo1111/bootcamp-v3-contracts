// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import { Exchange } from "./Exchange.sol";
import { Token } from "./Token.sol";
import { IFlashLoanReceiver } from "./FlashLoanProvider.sol";

contract FlashLoanUser is IFlashLoanReceiver {
    address exchange;

    event FlashLoanReceived(address token, uint256 amount);

    constructor(address _exchange) {
        exchange = _exchange;
    }

    function getFlashLoan(address _token, uint256 _amount) public {
        // Call the exchange for flash loan
        Exchange(exchange).flashloan(_token, _amount, "");
    }

    function receiveFlashloan(
        address _token,
        uint256 _amount,
        bytes memory /* _data */
    ) external {
        require(
            msg.sender == exchange,
            "FlashLoanUser: Not Exchange contract"
        );  

        // Do something with the loan
        emit FlashLoanReceived(_token, Token(_token).balanceOf(address(this)));

        // Repay the flash loan to the exchange
        require(
            Token(_token).transfer(exchange, _amount),
            "FlashLoanUser: Token transfer failed"
        );
    }
}
