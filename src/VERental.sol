pragma solidity ^0.8.0;

import {IVERental} from "./interfaces/IVERental.sol";
import {IVERentalEscrow} from "./interfaces/IVERentalEscrow.sol";
import {BaseTransfer} from "./base/BaseTransfer.sol";
import {VERentalEscrow} from "./VERentalEscrow.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract VERental is IVERental, BaseTransfer, Ownable {
    address public factory;
    address public escrow;
    address public buyer;
    address public seller;

    uint256 public lastVoteEpoch;
    uint256 public expiryEpoch;
    uint256 public tokenId;
    uint256 public price;

    uint256 public constant WEEK = 7 days;

    Status public currentStatus;

    bool public isReaped;

    constructor() BaseTransfer() Ownable(msg.sender) {}

    function initialize(
        address _seller,
        address _paymentToken,
        uint256 _veNFT,
        uint256 _amount,
        uint256 _duration
    ) external {
        if (factory != address(0)) revert AlreadyInitialized();
        factory = msg.sender;
        seller = _seller;
        tokenId = _veNFT;
        price = _amount;

        currentStatus = Status.Available;
        expiryEpoch = (block.timestamp + _duration) / WEEK;

        escrow = address(new VERentalEscrow(_paymentToken, _veNFT));
        _transferOwnership(_seller);
        emit Initialize(_seller, _paymentToken, _veNFT, _amount, _duration);
        emit StatusChange(currentStatus, block.timestamp);
    }

    function buy() external {
        uint256 nowEpoch = currentEpoch();

        if (nowEpoch >= expiryEpoch) revert Expired();
        if (currentStatus != Status.Available) revert RentedOut();

        uint256 multiplier = expiryEpoch - nowEpoch;

        _transferFromERC20(
            paymentToken,
            msg.sender,
            escrow,
            multiplier * price
        );

        IVERentalEscrow(escrow).updateBalance();

        buyer = msg.sender;
        currentStatus = Status.Rented_Out;
        emit StatusChange(currentStatus, block.timestamp);
        emit NewBuyer(buyer);
    }

    function vote(
        address[] calldata pools,
        uint256[] calldata weights
    ) external {
        if (currentStatus == Status.Expired) revert Expired();

        IVERentalEscrow(escrow).delegateVote(pools, weights);
        lastVoteEpoch = currentEpoch();

        IVERentalEscrow(escrow).updateBalance();
    }

    function reap() external {
        uint256 nowEpoch = currentEpoch();

        if (msg.sender != buyer) revert OnlyBuyer();
        if (isReaped) revert AlreadyReaped();

        IVERentalEscrow(escrow).updateBalance(); // Update balance before claim

        IVERentalEscrow(escrow).claim();
        isReaped = true;
        currentStatus = Status.Expired;

        IVERentalEscrow(escrow).updateBalance(); // We need to update balance in case payment token is also a reward token and has been disbursed after calling `claim`
    }

    function closeOutRental() external {
        if (msg.sender != seller && msg.sender != owner())
            revert UnallowedOperation();

        uint256 nowEpoch = currentEpoch();
        if (nowEpoch < expiryEpoch) revert StillRunning();
        if (currentStatus == Status.Expired && !isReaped) revert Expired();

        currentStatus = Status.Expired;
    }

    function currentEpoch() public view returns (uint256) {
        return block.timestamp / WEEK;
    }
}
