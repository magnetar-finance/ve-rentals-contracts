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
    uint256 public buyEpoch;
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
            IVERentalEscrow(escrow).paymentToken(),
            msg.sender,
            escrow,
            multiplier * price
        );

        IVERentalEscrow(escrow).updateBalance();

        buyEpoch = nowEpoch;
        buyer = msg.sender;
        currentStatus = Status.Rented_Out;
        emit StatusChange(currentStatus, block.timestamp);
        emit NewBuyer(buyer);
    }

    function vote(
        address[] calldata pools,
        uint256[] calldata weights
    ) external {
        if (msg.sender != buyer) revert OnlyBuyer();
        uint256 nowEpoch = currentEpoch();

        if (nowEpoch >= expiryEpoch) revert Expired();
        if (currentStatus == Status.Expired) revert Expired();

        IVERentalEscrow(escrow).delegateVote(pools, weights);
        lastVoteEpoch = currentEpoch();

        IVERentalEscrow(escrow).updateBalance();
    }

    function reap() external {
        if (msg.sender != buyer) revert OnlyBuyer();
        if (isReaped) revert AlreadyReaped();

        IVERentalEscrow(escrow).updateBalance(); // Update balance before claim so that escrow tracks balance before rewards

        IVERentalEscrow(escrow).claim();
        isReaped = true;
        currentStatus = Status.Expired;

        IVERentalEscrow(escrow).updateBalance(); // We need to update balance in case payment token is also a reward token and has been disbursed after calling `claim`
        emit StatusChange(currentStatus, block.timestamp);
    }

    function closeOutRental() external {
        if (msg.sender != seller && msg.sender != owner())
            revert UnallowedOperation();

        uint256 nowEpoch = currentEpoch();
        if (nowEpoch < expiryEpoch) revert StillRunning();
        if (currentStatus == Status.Expired) revert Expired();

        currentStatus = Status.Expired;

        IVERentalEscrow(escrow).close();
    }

    function currentEpoch() public view returns (uint256) {
        return block.timestamp / WEEK;
    }
}
