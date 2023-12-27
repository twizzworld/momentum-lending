/*

███╗░░░███╗░█████╗░███╗░░░███╗███████╗███╗░░██╗████████╗██╗░░░██╗███╗░░░███╗
████╗░████║██╔══██╗████╗░████║██╔════╝████╗░██║╚══██╔══╝██║░░░██║████╗░████║
██╔████╔██║██║░░██║██╔████╔██║█████╗░░██╔██╗██║░░░██║░░░██║░░░██║██╔████╔██║
██║╚██╔╝██║██║░░██║██║╚██╔╝██║██╔══╝░░██║╚████║░░░██║░░░██║░░░██║██║╚██╔╝██║
██║░╚═╝░██║╚█████╔╝██║░╚═╝░██║███████╗██║░╚███║░░░██║░░░╚██████╔╝██║░╚═╝░██║
╚═╝░░░░░╚═╝░╚════╝░╚═╝░░░░░╚═╝╚══════╝╚═╝░░╚══╝░░░╚═╝░░░░╚═════╝░╚═╝░░░░░╚═╝

██╗░░░░░███████╗███╗░░██╗██████╗░██╗███╗░░██╗░██████╗░
██║░░░░░██╔════╝████╗░██║██╔══██╗██║████╗░██║██╔════╝░
██║░░░░░█████╗░░██╔██╗██║██║░░██║██║██╔██╗██║██║░░██╗░
██║░░░░░██╔══╝░░██║╚████║██║░░██║██║██║╚████║██║░░╚██╗
███████╗███████╗██║░╚███║██████╔╝██║██║░╚███║╚██████╔╝
╚══════╝╚══════╝╚═╝░░╚══╝╚═════╝░╚═╝╚═╝░░╚══╝░╚═════╝░

*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract OvercollateralizedLendingProtocol {
    IERC20 public immutable lendingToken;
    IERC20 public immutable collateralToken;

    uint256 public constant COLLATERAL_FACTOR = 150; // 150%
    uint256 public loanInterestRate; // Interest rate per year

    uint256 public totalLiquidity;
    uint256 public totalInterestAccrued;

    struct Loan {
        uint256 amount;
        uint256 collateral;
        uint256 interestAccrued;
        uint256 startTime;
    }

    struct LiquidityProvider {
        uint256 depositAmount;
        uint256 interestShare;
    }

    mapping(address => Loan) public loans;
    mapping(address => LiquidityProvider) public liquidityProviders;

    constructor(IERC20 _lendingToken, IERC20 _collateralToken, uint256 _interestRate) {
        lendingToken = _lendingToken;
        collateralToken = _collateralToken;
        loanInterestRate = _interestRate;
    }

    function depositLiquidity(uint256 _amount) external {
        require(lendingToken.transferFrom(msg.sender, address(this), _amount), "Transfer failed");
        totalLiquidity += _amount;
        liquidityProviders[msg.sender].depositAmount += _amount;
    }

    function withdrawLiquidity(uint256 _amount) external {
        LiquidityProvider storage provider = liquidityProviders[msg.sender];
        require(provider.depositAmount >= _amount, "Insufficient funds");
        
        updateInterestShare(msg.sender);
        uint256 withdrawableAmount = _amount + provider.interestShare;
        provider.depositAmount -= _amount;
        provider.interestShare = 0;

        require(lendingToken.transfer(msg.sender, withdrawableAmount), "Transfer failed");
        totalLiquidity -= _amount;
    }

    // Other functions (depositCollateral, borrow, repay, etc.) remain unchanged

    function calculateInterest(uint256 _principal, uint256 _startTime) public view returns (uint256) {
        uint256 timeElapsed = block.timestamp - _startTime;
        uint256 interest = (_principal * loanInterestRate * timeElapsed) / (365 days * 100);
        return interest;
    }

    function distributeInterest(uint256 _interest) private {
        totalInterestAccrued += _interest;
        uint256 totalDeposited = totalLiquidity;
        for (address lp = firstLiquidityProvider; lp != address(0); lp = nextLiquidityProvider(lp)) {
            LiquidityProvider storage provider = liquidityProviders[lp];
            uint256 share = (provider.depositAmount * _interest) / totalDeposited;
            provider.interestShare += share;
        }
    }

    function updateInterestShare(address _provider) private {
        LiquidityProvider storage provider = liquidityProviders[_provider];
        uint256 share = (provider.depositAmount * totalInterestAccrued) / totalLiquidity;
        provider.interestShare = share;
    }

}
