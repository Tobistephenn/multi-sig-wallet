// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Library for managing addresses and their weight
library Address {
    function isContract(address account) internal view returns (bool) {
        // Check if the target address is a contract
        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }
}

// Base contract for inheritance
contract Ownable {
    address public owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid new owner");
        owner = newOwner;
    }
}

// Multi-signature wallet contract
contract MultiSigWallet is Ownable {
    using Address for address;

    // Mapping to track the owners and their respective weights
    mapping(address => uint256) public owners;
    uint256 public numConfirmationsRequired;

    // Transaction structure
    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        uint256 numConfirmations;
    }

    // Array of transactions
    Transaction[] public transactions;

    // Mapping to track confirmations for each transaction
    mapping(uint256 => mapping(address => bool)) public confirmations;

    event Deposit(address indexed sender, uint256 value, uint256 indexed txIndex);
    event Submission(uint256 indexed txIndex);
    event Execution(uint256 indexed txIndex);
    event ExecutionFailure(uint256 indexed txIndex);

    // Constructor to set up the wallet
    constructor(address[] memory _owners, uint256 _numConfirmationsRequired) {
        require(_owners.length > 0, "Owners required");
        require(
            _numConfirmationsRequired > 0 && _numConfirmationsRequired <= _owners.length,
            "Invalid number of confirmations"
        );

        for (uint256 i = 0; i < _owners.length; i++) {
            require(_owners[i] != address(0), "Invalid owner");
            require(!owners[_owners[i]].isContract(), "Owner cannot be a contract");
            require(owners[_owners[i]] == 0, "Duplicate owner");
            owners[_owners[i]] = 1;
        }

        numConfirmationsRequired = _numConfirmationsRequired;
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value, transactions.length);
    }

    // Submit a transaction for approval
    function submitTransaction(address _to, uint256 _value, bytes memory _data)
        external
        onlyOwner
    {
        uint256 txIndex = transactions.length;

        transactions.push(Transaction({
            to: _to,
            value: _value,
            data: _data,
            executed: false,
            numConfirmations: 0
        }));

        emit Submission(txIndex);
    }

    // Confirm a transaction
    function confirmTransaction(uint256 _txIndex) external onlyOwner {
        require(_txIndex < transactions.length, "Invalid transaction index");
        require(confirmations[_txIndex][msg.sender] == false, "Transaction already confirmed");

        transactions[_txIndex].numConfirmations += 1;
        confirmations[_txIndex][msg.sender] = true;

        emit Execution(_txIndex);

        if (transactions[_txIndex].numConfirmations >= numConfirmationsRequired) {
            executeTransaction(_txIndex);
        }
    }

    // Execute a transaction
    function executeTransaction(uint256 _txIndex) internal {
        require(_txIndex < transactions.length, "Invalid transaction index");
        require(!transactions[_txIndex].executed, "Transaction already executed");

        Transaction storage transaction = transactions[_txIndex];
        transaction.executed = true;

        (bool success, ) = transaction.to.call{value: transaction.value}(transaction.data);
        if (success) {
            emit Execution(_txIndex);
        } else {
            emit ExecutionFailure(_txIndex);
            transaction.executed = false;
        }
    }
}
