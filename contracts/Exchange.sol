// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import { Token } from "./Token.sol";

contract Exchange {
    // State variables
    address public feeAccount; // the account that receives exchange fees
    uint256 public feePercent; // the fee percentage
    uint256 public orderCount; // the number of orders created so far

    // Mappings
    mapping(uint256 => Order) public orders; // mapping of order id to Order

    // Total tokens belonging to a user
    mapping(address => mapping(address => uint256)) 
    private userTotalTokenBalance;
    // Total tokens on an active order
    mapping(address => mapping(address => uint256)) 
    private userActiveOrderTokenBalance;

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
    event OrderCreated(
        uint256 id,
        address user,
        address tokenGet,
        uint256 amountGet,
        address tokenGive,
        uint256 amountGive,
        uint256 timestamp
    );

    struct Order {
        // Attributes of an order
        uint256 id; // Unique identifier for order
        address user; // User who made order
        address tokenGet; // Address of the token they receive
        uint256 amountGet; // Amount they receive
        address tokenGive; // Address of token they give
        uint256 amountGive; // Amount they give
        uint256 timestamp; // When order was created
    }

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
        require(
            userTotalTokenBalance[_token][msg.sender] - 
            activeOrderBalanceOf(_token, msg.sender) >= 
            _amount,
         "Exchange: Insufficient balance");

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
    ) public view returns (uint256) {
        return userTotalTokenBalance[_token][_user];
    }

    function activeOrderBalanceOf(
        address _token,
        address _user
    ) public view returns (uint256) {
        return userActiveOrderTokenBalance[_token][_user];
    }

    // --- IGNORE ---
    // MAKE & CANCEL ORDERS

    function makeOrder(
        address _tokenGet,
        uint256 _amountGet,
        address _tokenGive,
        uint256 _amountGive    // Changed from address to uint256
    ) external {
        require(
            totalBalanceOf(_tokenGive, msg.sender) >=
                activeOrderBalanceOf(_tokenGive, msg.sender) + _amountGive,
            "Exchange: Insufficient balance");


        // Update order count
        orderCount++;

        // Instantiate a new order
        orders[orderCount] = Order(
            orderCount,
            msg.sender,
            _tokenGet,
            _amountGet,
            _tokenGive,
            _amountGive,
            block.timestamp
        );
        
        // Update the users active balance
        userActiveOrderTokenBalance[_tokenGive][msg.sender] += _amountGive;

        // Emit an event
        emit OrderCreated(
            orderCount,
            msg.sender,
            _tokenGet,
            _amountGet,
            _tokenGive,
            _amountGive,
            block.timestamp
        );
    }

}

