pragma solidity ^0.8.0;

interface IVERentalEscrow {
    error OnlyFactory();
    error OnlyNewEpoch();
    error ExpiryEpoch();

    event VoteDelegated(uint256 timestamp, uint256 epoch);

    function claim() external;

    function close() external;

    function updateBalance() external;

    function delegateVote(
        address[] calldata pools,
        uint256[] calldata weights
    ) external;

    function tokenId() external view returns (uint256);

    function paymentToken() external view returns (address);

    function trackedPTBalance() external view returns (uint256);

    function factory() external view returns (address);
}
