// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract Escrow is Initializable, OwnableUpgradeable {
    //enum for store the payement status
    enum State {
        AWAITING_PAYMENT,
        AWAITING_DELIVERY,
        COMPLETE,
        DISPUTE
    }

    //structure to store the Transaction details
    struct Transaction {
        uint256 amount;
        address sender;
        address receiver;
        address arbitrator;
        State state;
        uint8 approvals;
        mapping(address => bool) approvers;
    }

    //contracts events
    event Deposited(
        uint256 indexed txId,
        address indexed sender,
        uint256 amount
    );
    event Released(
        uint256 indexed txId,
        address indexed receiver,
        uint256 amount
    );
    event Refunded(
        uint256 indexed txId,
        address indexed sender,
        uint256 amount
    );
    event DisputeResolved(uint256 indexed txId, address indexed resolver);

    //state variables
    uint256 public transactionCounter;

    //mapping
    mapping(uint256 => Transaction) public transactions;

    function initialize() public initializer {
        __Ownable_init(msg.sender);
    }

    /*** 
        @notice deposite funds
        @param _receiver The receiver of transaction
        @param _arbitrator The arbitrator of transaction
        @param _amount The _amount of transaction which is deposit

    **/
    function deposit(
        address _receiver,
        address _arbitrator,
        uint256 _amount
    ) external payable {
        require(msg.value > 0, "value could not be zero");
        require(_amount > 0 && _amount == msg.value, "amount should be valid");

        _incrementTransactionCounter();
        uint256 _transactionCounter = transactionCounter;
        Transaction storage txn = transactions[_transactionCounter];
        txn.amount = _amount;
        txn.sender = msg.sender;
        txn.receiver = _receiver;
        txn.arbitrator = _arbitrator;
        txn.state = State.AWAITING_DELIVERY;
        txn.approvals = 0;

        emit Deposited(transactionCounter, msg.sender, msg.value);
    }

    /*** 
        @notice approve transaction
        @param _txId The transaction id
    **/
    function approve(uint256 _txId) external {
        Transaction storage txn = transactions[_txId];
        require(
            txn.state == State.AWAITING_DELIVERY,
            "cannot approve wating for transaction delivery"
        );
        require(
            msg.sender == txn.sender ||
                msg.sender == txn.receiver ||
                msg.sender == txn.arbitrator,
            "Not authorized"
        );
        require(!txn.approvers[msg.sender], " transaction is already approved");
        txn.approvers[msg.sender] = true;
        txn.approvals++;
        // check transaction approval
        if (txn.approvals >= 2) {
            release(_txId);
        }
    }

    /*** 
        @notice release transaction
        @param _txId The transaction id
    **/
    function release(uint256 _txId) internal {
        Transaction storage txn = transactions[_txId];
        require(
            txn.state == State.AWAITING_DELIVERY,
            "cannot release transaction"
        );
        require(txn.approvals >= 2, "Not enough approvals");
        txn.state = State.COMPLETE;
        // transfer amount to receiver
        payable(txn.receiver).transfer(txn.amount);

        emit Released(_txId, txn.receiver, txn.amount);
    }

    /*** 
        @notice dispute transaction to allowing a third-party arbitrator to resolve conflicts
        @param _txId The transaction id
    **/
    function dispute(uint256 _txId) external {
        Transaction storage txn = transactions[_txId];
        require(
            msg.sender == txn.sender || msg.sender == txn.receiver,
            "you are not authorized"
        );
        txn.state = State.DISPUTE;
    }

    /*** 
        @notice resolve Dispute
        @param _txId The transaction id
        @param releaseFunds allow release the funds
    **/
    function resolveDispute(uint256 _txId, bool releaseFunds) external {
        Transaction storage txn = transactions[_txId];
        require(
            txn.state == State.DISPUTE,
            "transaction in not in dispute state"
        );
        require(
            msg.sender == txn.arbitrator,
            "you are not authorized as arbitrator"
        );
        if (releaseFunds) {
            release(_txId);
        } else {
            refund(_txId);
        }

        emit DisputeResolved(_txId, msg.sender);
    }

    /***
        Internal method
    **/

    /*** 
        @notice refund transaction
        @param _txId The transaction id
    **/
    function refund(uint256 _txId) internal {
        Transaction storage txn = transactions[_txId];
        require(txn.state == State.AWAITING_DELIVERY, "Cannot refund");
        require(
            msg.sender == txn.sender || msg.sender == txn.arbitrator,
            "you are not authorized"
        );
        txn.state = State.COMPLETE;
        // transfer amount to sender
        payable(txn.sender).transfer(txn.amount);

        emit Refunded(_txId, txn.sender, txn.amount);
    }

    /*** 
        @notice increment Transaction Counter
    **/
    function _incrementTransactionCounter() internal {
        transactionCounter++;
    }
}
