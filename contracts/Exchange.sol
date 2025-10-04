// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import { Token } from "./Token.sol";

contract Exchange {
    // State variables
    address public feeAccount; // the account that receives exchange fees
    uint256 public feePercent; // the fee percentage

    // Total tokens belonging to a user
    mapping(address => mapping(address => uint256)) 
    private userTotalTokenBalance;

    // Events
    event TokensDeposited(
        address token,
        address user,
        uint256 amount,
        uint256 balance
    );
    event TokensWithdrawn(
        address token,
        address user,
        uint256 amount,
        uint256 balance
    );

    constructor(address _feeAccount, uint256 _feePercent) {
        feeAccount = _feeAccount;
        feePercent = _feePercent;
    }


    // -----------------------
    // DEPOSIT & WITHDRAWAL TOKENS

    function depositToken(address _token, uint256 _amount) external {
        // Update user balance
        userTotalTokenBalance[_token][msg.sender] += _amount;

        // Emit an event
        emit TokensDeposited(
            _token, 
            msg.sender, 
            _amount, 
            userTotalTokenBalance[_token][msg.sender]
        );

        // Transfer tokens to exchange
        require(
            Token(_token).transferFrom(msg.sender, address(this), _amount),
            "Exchange: Token transfer failed"
        );
    }

    function withdrawToken(address _token, uint256 _amount) external {
        require(userTotalTokenBalance[_token][msg.sender] >= _amount, "Exchange: Insufficient balance");

        // Update The User Balance
        userTotalTokenBalance[_token][msg.sender] -= _amount;

        // Emit an Event
        emit TokensWithdrawn(
            _token, 
            msg.sender, 
            _amount, 
            userTotalTokenBalance[_token][msg.sender]
        );

        // Transfer Tokens back to User
        require(Token(_token).transfer(msg.sender, _amount),
        "Exchange: Token transfer failed");

    }

    function totalBalanceOf(
        address _token,
        address _user
    ) external view returns (uint256) {
        return userTotalTokenBalance[_token][_user];
    }
}
