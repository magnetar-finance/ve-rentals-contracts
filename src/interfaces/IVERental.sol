pragma solidity ^0.8.0;

interface IVERental {
    enum Status {
        Available,
        Expired,
        Rented_Out
    }

    error OnlyFactory();
    error RentedOut();
    error Expired();
    error AlreadyInitialized();
    error OnlyBuyer();
    error AlreadyReaped();
    error UnallowedOperation();
    error StillRunning();

    event Initialize(
        address indexed seller,
        address indexed paymentToken,
        uint256 indexed tokenId,
        uint256 amount,
        uint256 duration
    );
    event StatusChange(Status newStatus, uint256 timestamp);
    event NewBuyer(address buyer);
    event Reaped();

    /// === State modifiers === ///

    function initialize(
        address seller,
        address paymentToken,
        uint256 veNFT,
        uint256 amount,
        uint256 duration
    ) external;

    function buy() external;

    function vote(
        address[] calldata pools,
        uint256[] calldata weights
    ) external;

    function reap() external;

    function closeOutRental() external;

    /// === View functions === ///

    function factory() external view returns (address);

    function price() external view returns (uint256);

    function escrow() external view returns (address);

    function buyer() external view returns (address);

    function seller() external view returns (address);

    function lastVoteEpoch() external view returns (uint256);

    function buyEpoch() external view returns (uint256);

    function currentEpoch() external view returns (uint256);

    function expiryEpoch() external view returns (uint256);

    function currentStatus() external view returns (Status);

    function tokenId() external view returns (uint256);

    function isReaped() external view returns (bool);
}
