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
    mapping(uint256 => bool) public isOrderCancelled; // mapping of order id to cancelled
    // (optionally) mapping(uint256 => bool) public isOrderFilled;

    // Total tokens belonging to a user
    mapping(address => mapping(address => uint256)) private userTotalTokenBalance;
    // Total tokens on an active order
    mapping(address => mapping(address => uint256)) private userActiveOrderTokenBalance;

    // Events
    event TokensDeposited(address token, address user, uint256 amount, uint256 balance);
    event TokensWithdrawn(address token, address user, uint256 amount, uint256 balance);
    event OrderCreated(
        uint256 id,
        address user,
        address tokenGet,
        uint256 amountGet,
        address tokenGive,
        uint256 amountGive,
        uint256 timestamp
    );
        event OrderCancelled(
        uint256 id,
        address user,
        address tokenGet,
        uint256 amountGet,
        address tokenGive,
        uint256 amountGive,
        uint256 timestamp
    );

    struct Order {
        uint256 id;
        address user;
        address tokenGet;
        uint256 amountGet;
        address tokenGive;
        uint256 amountGive;
        uint256 timestamp;
    }

    constructor(address _feeAccount, uint256 _feePercent) {
        feeAccount = _feeAccount;
        feePercent = _feePercent;
    }

    // -----------------------
    // DEPOSIT & WITHDRAWAL TOKENS

    function depositToken(address _token, uint256 _amount) external {
        // Transfer tokens to exchange first
        require(
            Token(_token).transferFrom(msg.sender, address(this), _amount),
            "Exchange: transferFrom failed"
        );

        // Update user balance
        userTotalTokenBalance[_token][msg.sender] += _amount;

        // Emit an event
        emit TokensDeposited(
            _token,
            msg.sender,
            _amount,
            userTotalTokenBalance[_token][msg.sender]
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
        require(
            Token(_token).transfer(msg.sender, _amount),
            "Exchange: Token transfer failed"
        );
    }

    function totalBalanceOf(address _token, address _user) public view returns (uint256) {
        return userTotalTokenBalance[_token][_user];
    }

    function activeOrderBalanceOf(address _token, address _user) public view returns (uint256) {
        return userActiveOrderTokenBalance[_token][_user];
    }

    // --- ORDERS ---

    function makeOrder(
        address _tokenGet,
        uint256 _amountGet,
        address _tokenGive,
        uint256 _amountGive
    ) external {
        require(userTotalTokenBalance[_tokenGive][msg.sender] >= _amountGive, "Exchange: Insufficient balance");

        // Update order count
        orderCount++;

        // Instantiate a new order
        orders[orderCount] = Order({
            id: orderCount,
            user: msg.sender,
            tokenGet: _tokenGet,
            amountGet: _amountGet,
            tokenGive: _tokenGive,
            amountGive: _amountGive,
            timestamp: block.timestamp
        });

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

    function cancelOrder(uint256 _id) external {
        Order storage order = orders[_id];

        // Ensure the order exists
        require(order.id == _id, "Exchange: order does not exist");

        // Ensure the caller of the function is the owner of the order
        require(address(order.user) == msg.sender, "Exchange: not the order owner");

        // Cancel the order
        isOrderCancelled[_id] = true;

        // Update the active balance
        userActiveOrderTokenBalance[order.tokenGive][order.user] -= order.amountGive;

        // Emit an event
        emit OrderCancelled(
            order.id,
            order.user,
            order.tokenGet,
            order.amountGet,
            order.tokenGive,
            order.amountGive,
            block.timestamp
        );
    }
}

