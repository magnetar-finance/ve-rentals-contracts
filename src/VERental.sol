pragma solidity ^0.8.0;

import {IVERental} from "./interfaces/IVERental.sol";
import {IVERentalEscrow} from "./interfaces/IVERentalEscrow.sol";
import {BaseTransfer} from "./base/BaseTransfer.sol";
import {VERentalEscrow} from "./VERentalEscrow.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract VERental is IVERental, BaseTransfer, Ownable, ReentrancyGuard {
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
    uint256 public constant MAX_REWARDS_COMMISSION = 100; // 1%
    uint256 public rewardsCommission;

    Status public currentStatus;

    bool public isReaped;

    constructor() BaseTransfer() Ownable(msg.sender) {}

    function initialize(
        address _seller,
        address _paymentToken,
        uint256 _veNFT,
        uint256 _amount,
        uint256 _duration,
        uint256 _rewardsCommission
    ) external nonReentrant {
        if (factory != address(0)) revert AlreadyInitialized();
        factory = msg.sender;
        seller = _seller;
        tokenId = _veNFT;
        price = _amount;

        currentStatus = Status.Available;
        expiryEpoch = (block.timestamp + _duration) / WEEK;
        rewardsCommission = _rewardsCommission;

        require(_rewardsCommission <= MAX_REWARDS_COMMISSION);

        escrow = address(new VERentalEscrow(_paymentToken, _veNFT));
        _transferOwnership(_seller);
        emit Initialize(
            _seller,
            _paymentToken,
            _veNFT,
            _amount,
            _duration,
            _rewardsCommission
        );
        emit StatusChange(currentStatus, block.timestamp);
    }

    function buy() external nonReentrant {
        uint256 nowEpoch = currentEpoch();

        if (nowEpoch >= expiryEpoch) revert Expired();
        if (currentStatus != Status.Available) revert RentedOut();

        uint256 multiplier = expiryEpoch - nowEpoch;

        address paymentToken = IVERentalEscrow(escrow).paymentToken();
        uint256 balanceBefore = IERC20(paymentToken).balanceOf(escrow);
        _transferFromERC20(
            paymentToken,
            msg.sender,
            escrow,
            multiplier * price
        );
        uint256 balanceAfter = IERC20(paymentToken).balanceOf(escrow);

        uint256 deposited = balanceAfter - balanceBefore;
        require(deposited == multiplier * price, "Exact amount required");

        IVERentalEscrow(escrow).increaseTrackedBalance(deposited);

        buyEpoch = nowEpoch;
        buyer = msg.sender;
        currentStatus = Status.Rented_Out;
        emit StatusChange(currentStatus, block.timestamp);
        emit NewBuyer(buyer);
    }

    function vote(
        address[] calldata pools,
        uint256[] calldata weights
    ) external nonReentrant {
        if (msg.sender != buyer) revert OnlyBuyer();
        uint256 nowEpoch = currentEpoch();

        if (nowEpoch >= expiryEpoch) revert Expired();
        if (currentStatus == Status.Expired) revert Expired();

        IVERentalEscrow(escrow).delegateVote(pools, weights);
        lastVoteEpoch = currentEpoch();
    }

    function reap() external nonReentrant {
        if (msg.sender != buyer) revert OnlyBuyer();
        if (isReaped) revert AlreadyReaped();

        uint256 nowEpoch = currentEpoch();
        if (nowEpoch < expiryEpoch) revert StillRunning();

        IVERentalEscrow(escrow).claim();
        isReaped = true;

        if (currentStatus != Status.Expired) {
            currentStatus = Status.Expired;
            emit StatusChange(currentStatus, block.timestamp);
        }

        emit Reaped();
    }

    function closeOutRental() external nonReentrant {
        if (msg.sender != seller && msg.sender != owner())
            revert UnallowedOperation();

        uint256 nowEpoch = currentEpoch();
        if (nowEpoch < expiryEpoch) revert StillRunning();

        // Claim rewards if not yet reaped
        if (!isReaped) {
            IVERentalEscrow(escrow).claim();
            isReaped = true;
            emit Reaped();
        }

        if (currentStatus != Status.Expired) {
            currentStatus = Status.Expired;
            emit StatusChange(currentStatus, block.timestamp);
        }

        IVERentalEscrow(escrow).close();
    }

    function emergencyClose() external {
        if (msg.sender != seller && msg.sender != owner())
            revert UnallowedOperation();

        uint256 nowEpoch = currentEpoch();
        if (nowEpoch <= expiryEpoch + 1) revert StillRunning();

        if (currentStatus != Status.Expired) {
            currentStatus = Status.Expired;
            emit StatusChange(currentStatus, block.timestamp);
        }

        IVERentalEscrow(escrow).close();
    }

    function currentEpoch() public view returns (uint256) {
        return block.timestamp / WEEK;
    }
}
