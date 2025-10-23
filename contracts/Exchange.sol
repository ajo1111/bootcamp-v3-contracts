// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Token} from "./Token.sol";
import {FlashLoanProvider} from "./FlashLoanProvider.sol";

contract Exchange is FlashLoanProvider {
    // State variables
    address public feeAccount; // the account that receives exchange fees
    uint256 public feePercent; // the fee percentage
    uint256 public orderCount; // the number of orders created so far

    // Mappings
    mapping(uint256 => Order) public orders; // mapping of order id to Order
    mapping(uint256 => bool) public isOrderCancelled; // mapping of order id to cancelled
    mapping(uint256 => bool) public isOrderFilled;

    // Total tokens belonging to a user
    mapping(address => mapping(address => uint256))
        private userTotalTokenBalance;
    // Total tokens on an active order
    mapping(address => mapping(address => uint256))
        private userActiveTokenBalance;

    
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
        event OrderCancelled(
        uint256 id,
        address user,
        address tokenGet,
        uint256 amountGet,
        address tokenGive,
        uint256 amountGive,
        uint256 timestamp
    );
        event OrderFilled(
        uint256 id,
        address user,
        address tokenGet,
        uint256 amountGet,
        address tokenGive,
        uint256 amountGive,
        address creator,
        uint256 timestamp
    );

    struct Order {
        // Attributes of an order
        uint256 id; // unique identifier for the order
        address user; // the user who made the order
        address tokenGet; // Address of the token they receive
        uint256 amountGet; // Amount they receive
        address tokenGive; // Address of the token they give
        uint256 amountGive; // Amount they give
        uint256 timestamp; // When the order was created
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

        // Transfer Tokens to Exchange
        require(
            Token(_token).transferFrom(msg.sender, address(this), _amount),
            "Exchange: Token transfer failed"
        );
    }

    function withdrawToken(address _token, uint256 _amount) external {
        require(
            totalBalanceOf(_token, msg.sender) -
                activeBalanceOf(_token, msg.sender) >=
                _amount, 
            "Exchange: Insufficient balance"
        );

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

    function totalBalanceOf(
        address _token,
        address _user
    ) public view returns (uint256) {
        return userTotalTokenBalance[_token][_user];
    }

    function activeBalanceOf(
        address _token,
        address _user
    ) public view returns (uint256) {
        return userActiveTokenBalance[_token][_user];
    }

    // --------------------------
    // MAKE & CANCEL ORDERS

    function makeOrder(
        address _tokenGet,
        uint256 _amountGet,
        address _tokenGive,
        uint256 _amountGive
    ) external {
        require(
            totalBalanceOf(_tokenGive, msg.sender) >=
                activeBalanceOf(_tokenGive, msg.sender) + _amountGive,
                "Exchange: Insufficient balance"
        );

        // Update order count
        orderCount ++;

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
        userActiveTokenBalance[_tokenGive][msg.sender] += _amountGive;

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
        // Fetch order
        Order storage order = orders[_id];

        // Order must exist
        require(order.id == _id, "Exchange: order does not exist");

        // Ensure the caller of the function is the owner of the order
        require(address(order.user) == msg.sender, "Exchange: not the order owner");

        // Cancel the order
        isOrderCancelled[_id] = true;

        // Update user's active token balance
        userActiveTokenBalance[order.tokenGive][order.user] -= order.amountGive;

        // Emit an event
        emit OrderCancelled(
            order.id,
            msg.sender,
            order.tokenGet,
            order.amountGet,
            order.tokenGive,
            order.amountGive,
            block.timestamp
        );
    }

    // --------------------------
    // EXECUTING ORDERS -----

    function fillOrder(uint256 _id) external {  
        // 1. Must be valid orderId
        require(_id > 0 && _id <= orderCount, "Exchange: order does not exist");
        // 2. Order can't be filled
        require(!isOrderFilled[_id], "Exchange: order has already been filled");
        // 3. Order can't be cancelled
        require(!isOrderCancelled[_id], "Exchange: order has been cancelled");

        // FETCH the order
        Order storage order = orders[_id];

        // Present filling if msg.sender already has their tokens listed
        require(
            totalBalanceOf(order.tokenGet, msg.sender) >= 
                activeBalanceOf(order.tokenGet, msg.sender) + order.amountGet,
            "Exchange: insufficient balance"
        );

        // Execute the trade
        _trade(
            order.id,
            order.user,
            order.tokenGet,
            order.amountGet,
            order.tokenGive,
            order.amountGive
        );

        // Mark order as filled
        isOrderFilled[order.id] = true;
    }

    function _trade(
        uint256 _orderId,
        address _user,
        address _tokenGet,
        uint256 _amountGet,
        address _tokenGive,
        uint256 _amountGive
    ) internal {
        //Fee is paid by the user who filled the order (msg.sender)
        //Fee is deducted from _amountGet
        uint256 _feeAmount = (_amountGet * feePercent) / 100;

        // Execute the trade
        // Let the user who created the order get their tokens
        userTotalTokenBalance[_tokenGet][msg.sender] -= (_amountGet +
            _feeAmount);
        userTotalTokenBalance[_tokenGet][_user] += _amountGet;

        // Charge the fee
        userTotalTokenBalance[_tokenGet][feeAccount] += _feeAmount;

        // Give the requested token to msg.sender, and minus token balance from
        // the user who created the order
        userTotalTokenBalance[_tokenGive][_user] -= _amountGive;
        userTotalTokenBalance[_tokenGive][msg.sender] += _amountGive;

        // Update user's active order balance
        userActiveTokenBalance[_tokenGive][_user] -= _amountGive;

        // Emit trade event
        emit OrderFilled(
            _orderId,
            msg.sender,
            _tokenGet,
            _amountGet,
            _tokenGive,
            _amountGive,
            _user,
            block.timestamp
        );
    }

}


