// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Import necessary libraries and interfaces
import "./IERC20.sol";
import "./SafeMath.sol";

contract LendingProtocol {
    using SafeMath for uint256;

    // Struct to represent a loan
    struct Loan {
        address borrower;
        uint256 amount;
        uint256 interestRate;
        uint256 duration; // in seconds
        uint256 startTime;
        bool isActive;
    }

    // State variables
    IERC20 public token; // The token used for lending
    address public owner;
    Loan[] public loans;
    uint256 public totalLoans;

    // Mapping to keep track of user balances
    mapping(address => uint256) public balances;

    // Events
    event LoanCreated(address indexed borrower, uint256 loanAmount, uint256 duration);
    event LoanRepaid(address indexed borrower, uint256 repaidAmount);

    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can call this function");
        _;
    }

    // Constructor to initialize the contract
    constructor(address _tokenAddress) {
        token = IERC20(_tokenAddress);
        owner = msg.sender;
    }

    // Function to allow users to borrow funds
    function borrow(uint256 _amount, uint256 _interestRate, uint256 _duration) external {
        require(_amount > 0, "Amount must be greater than 0");
        require(_interestRate > 0, "Interest rate must be greater than 0");
        require(_duration > 0, "Duration must be greater than 0");

        // Transfer tokens from borrower to the contract
        token.transferFrom(msg.sender, address(this), _amount);

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

    // Function to allow users to repay their loans
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

    // Function to withdraw available funds from the contract
    function withdraw(uint256 _amount) external onlyOwner {
        require(_amount <= address(this).balance, "Insufficient contract balance");
        payable(owner).transfer(_amount);
    }
}
