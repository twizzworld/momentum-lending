// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./OvercollateralizedLendingProtocol.sol";

contract OvercollateralizedLendingProtocolFactory {
    // Event to emit when a new OvercollateralizedLendingProtocol is created
    event ProtocolCreated(address indexed protocolAddress);

    // Function to create a new OvercollateralizedLendingProtocol
    function createProtocol(
        IERC20 _lendingToken,
        IERC20 _collateralToken,
        uint256 _interestRate
    ) public returns (address) {
        OvercollateralizedLendingProtocol newProtocol = new OvercollateralizedLendingProtocol(
            _lendingToken,
            _collateralToken,
            _interestRate
        );
        emit ProtocolCreated(address(newProtocol));
        return address(newProtocol);
    }

}
