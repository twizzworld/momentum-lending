// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IERC20.sol";
import "./SafeMath.sol";

contract LendingProtocol {
    using SafeMath for uint256;

    struct Loan {
        address borrower;
        uint256 amount;
        uint256 interestRate;
        uint256 duration; // in seconds
        uint256 startTime;
        bool isActive;
    }

    struct LendingPool {
        uint256 totalDeposits;
        mapping(address => uint256) deposits;
    }

    IERC20 public token;
    address public owner;
    Loan[] public loans;
    LendingPool public lendingPool;
    uint256 public totalLoans;

    mapping(address => uint256) public balances;

    event LoanCreated(address indexed borrower, uint256 loanAmount, uint256 duration);
    event LoanRepaid(address indexed borrower, uint256 repaidAmount);
    event DepositMade(address indexed depositor, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can call this function");
        _;
    }

    constructor(address _tokenAddress) {
        token = IERC20(_tokenAddress);
        owner = msg.sender;
    }

    function borrow(uint256 _amount, uint256 _interestRate, uint256 _duration) external {
        require(_amount > 0, "Amount must be greater than 0");
        require(_interestRate > 0, "Interest rate must be greater than 0");
        require(_duration > 0, "Duration must be greater than 0");

        uint256 availableFunds = lendingPool.deposits[msg.sender];
        require(availableFunds >= _amount, "Insufficient available funds");

        // Transfer tokens from the lending pool to the borrower
        lendingPool.deposits[msg.sender] = availableFunds.sub(_amount);

        // Create a new loan
        Loan memory newLoan = Loan({
            borrower: msg.sender,
            amount: _amount,
            interestRate: _interestRate,
            duration: _duration,
            startTime: block.timestamp,
            isActive: true
        });

        loans.push(newLoan);
        totalLoans++;

        // Emit an event to log the loan creation
        emit LoanCreated(msg.sender, _amount, _duration);
    }

    function repay(uint256 _loanIndex, uint256 _amount) external {
        require(_loanIndex < loans.length, "Invalid loan index");
        Loan storage loan = loans[_loanIndex];

        require(loan.isActive, "Loan is not active");
        require(msg.sender == loan.borrower, "Only the borrower can repay the loan");

        // Calculate the interest
        uint256 interest = loan.amount.mul(loan.interestRate).div(100).mul(block.timestamp.sub(loan.startTime)).div(1 days);

        // Calculate the total amount to repay
        uint256 totalAmountToRepay = loan.amount.add(interest);

        require(_amount >= totalAmountToRepay, "Insufficient repayment amount");

        // Transfer the repayment amount to the contract
        token.transferFrom(msg.sender, address(this), totalAmountToRepay);

        // Update user balances
        balances[msg.sender] = balances[msg.sender].sub(totalAmountToRepay);

        // Mark the loan as repaid
        loan.isActive = false;

        // Emit an event to log the loan repayment
        emit LoanRepaid(msg.sender, totalAmountToRepay);
    }

    function deposit(uint256 _amount) external {
        require(_amount > 0, "Amount must be greater than 0");

        // Transfer tokens from the depositor to the lending pool
        token.transferFrom(msg.sender, address(this), _amount);

        // Update the lending pool and user balances
        lendingPool.totalDeposits = lendingPool.totalDeposits.add(_amount);
        lendingPool.deposits[msg.sender] = lendingPool.deposits[msg.sender].add(_amount);

        // Emit an event to log the deposit
        emit DepositMade(msg.sender, _amount);
    }

    function withdraw(uint256 _amount) external onlyOwner {
        require(_amount <= address(this).balance, "Insufficient contract balance");
        payable(owner).transfer(_amount);
    }
}
