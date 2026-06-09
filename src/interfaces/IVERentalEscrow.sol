pragma solidity ^0.8.0;

interface IVERentalEscrow {
    function claim(uint256 amount) external;

    function tokenId() external view returns (uint256);

    function paymentToken() external view returns (address);

    function trackedPTBalance() external view returns (uint256);
}
