pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IVERentalEscrow} from "./interfaces/IVERentalEscrow.sol";
import {IVERentalMarketplace} from "./interfaces/IVERentalMarketplace.sol";
import {IVERental} from "./interfaces/IVERental.sol";
import {IVotingEscrow} from "./interfaces/IVotingEscrow.sol";
import {IVoter} from "./interfaces/IVoter.sol";
import {IReward} from "./interfaces/IReward.sol";
import {BaseTransfer} from "./base/BaseTransfer.sol";

contract VERentalEscrow is IVERentalEscrow, BaseTransfer {
    address public paymentToken;
    address public factory;

    address[] public votedPools;

    uint256 public tokenId;
    uint256 public trackedPTBalance;

    IVoter public voter;

    constructor(address _paymentToken, uint256 _tokenId) BaseTransfer() {
        paymentToken = _paymentToken;
        tokenId = _tokenId;
        factory = msg.sender;

        voter = IVoter(
            IVotingEscrow(IVERentalMarketplace(factory).ve()).voter()
        );
    }

    function updateBalance() public {
        if (msg.sender != factory) revert OnlyFactory();

        trackedPTBalance = IERC20(paymentToken).balanceOf(address(this));
    }

    function delegateVote(
        address[] calldata pools,
        uint256[] calldata weights
    ) external {
        if (msg.sender != factory) revert OnlyFactory();

        uint256 currentEpoch = IVERental(factory).currentEpoch();
        uint256 lastVoteEpoch = IVERental(factory).lastVoteEpoch();
        uint256 expiryEpoch = IVERental(factory).expiryEpoch();

        if (currentEpoch == lastVoteEpoch) revert OnlyNewEpoch();
        if (currentEpoch >= expiryEpoch) revert ExpiryEpoch();

        uint256 multiplier = lastVoteEpoch == 0
            ? 1
            : currentEpoch - lastVoteEpoch;
        uint256 rentDue = multiplier * IVERental(factory).price();

        _transferERC20(paymentToken, IVERental(factory).seller(), rentDue);

        voter.vote(tokenId, pools, weights);
        _trackPools(pools);
    }

    function claim() external {
        if (msg.sender != factory) revert OnlyFactory();

        // Claim rewards
        _claimGaugeRewards();
        _claimBribeRewards();
        _claimFeeRewards();

        // Release rewards
        _releaseMGN();
        _releaseBribeRewards();
        _releaseFeeRewards();
    }

    function _claimGaugeRewards() internal {
        address[] memory gauges = new address[](votedPools.length);

        for (uint i = 0; i < votedPools.length; i++) {
            gauges[i] = voter.gauges(votedPools[i]);
        }

        voter.claimRewards(gauges);
    }

    function _claimBribeRewards() internal {
        address[] memory bribes = new address[](votedPools.length);

        for (uint i = 0; i < votedPools.length; i++) {
            address gauge = voter.gauges(votedPools[i]);
            bribes[i] = voter.gaugeToBribe(gauge);
        }

        address[][] memory rewardTokens = new address[][](bribes.length);

        for (uint i = 0; i < bribes.length; i++) {
            uint256 tokensLength = IReward(bribes[i]).rewardsListLength();
            rewardTokens[i] = new address[](tokensLength);

            for (uint j = 0; j < tokensLength; j++) {
                rewardTokens[i][j] = IReward(bribes[i]).rewards(j);
            }
        }

        voter.claimBribes(bribes, rewardTokens, tokenId);
    }

    function _claimFeeRewards() internal {
        address[] memory fees = new address[](votedPools.length);

        for (uint i = 0; i < votedPools.length; i++) {
            address gauge = voter.gauges(votedPools[i]);
            fees[i] = voter.gaugeToFees(gauge);
        }

        address[][] memory rewardTokens = new address[][](fees.length);

        for (uint i = 0; i < fees.length; i++) {
            uint256 tokensLength = IReward(fees[i]).rewardsListLength();
            rewardTokens[i] = new address[](tokensLength);

            for (uint j = 0; j < tokensLength; j++) {
                rewardTokens[i][j] = IReward(fees[i]).rewards(j);
            }
        }

        voter.claimFees(fees, rewardTokens, tokenId);
    }

    function _releaseMGN() internal {
        address mgn = IVotingEscrow(IVERentalMarketplace(factory).ve()).token();
        // Get balance
        uint256 tokenBalance = IERC20(mgn).balanceOf(address(this));
        // Update token balance if reward token is payment token
        if (mgn == paymentToken) {
            tokenBalance -= trackedPTBalance;
        }
        // Buyer
        address buyer = IVERental(factory).buyer();
        // Send out reward
        _transferERC20(mgn, buyer, tokenBalance);
    }

    function _releaseBribeRewards() internal {
        address[] memory bribes = new address[](votedPools.length);

        for (uint i = 0; i < votedPools.length; i++) {
            address gauge = voter.gauges(votedPools[i]);
            bribes[i] = voter.gaugeToBribe(gauge);
        }

        for (uint i = 0; i < bribes.length; i++) {
            uint256 tokensLength = IReward(bribes[i]).rewardsListLength();

            for (uint j = 0; j < tokensLength; j++) {
                address reward = IReward(bribes[i]).rewards(j);
                // Get balance
                uint256 tokenBalance = IERC20(reward).balanceOf(address(this));
                // Update token balance if reward token is payment token
                if (reward == paymentToken) {
                    tokenBalance -= trackedPTBalance;
                }
                // Buyer
                address buyer = IVERental(factory).buyer();
                // Send out reward
                _transferERC20(reward, buyer, tokenBalance);
            }
        }
    }

    function _releaseFeeRewards() internal {
        address[] memory fees = new address[](votedPools.length);

        for (uint i = 0; i < votedPools.length; i++) {
            address gauge = voter.gauges(votedPools[i]);
            fees[i] = voter.gaugeToFees(gauge);
        }

        for (uint i = 0; i < fees.length; i++) {
            uint256 tokensLength = IReward(fees[i]).rewardsListLength();

            for (uint j = 0; j < tokensLength; j++) {
                address reward = IReward(fees[i]).rewards(j);
                // Get balance
                uint256 tokenBalance = IERC20(reward).balanceOf(address(this));
                // Update token balance if reward token is payment token
                if (reward == paymentToken) {
                    tokenBalance -= trackedPTBalance;
                }
                // Buyer
                address buyer = IVERental(factory).buyer();
                // Send out reward
                _transferERC20(reward, buyer, tokenBalance);
            }
        }
    }

    function _trackPools(address[] memory _pools) internal {
        for (uint i = 0; i < _pools.length; i++) {
            if (_checkPoolTracked(_pools[i])) {
                continue;
            }
            votedPools.push(_pools[i]);
        }
    }

    function _checkPoolTracked(address pool) internal view returns (bool) {
        for (uint i = 0; i < votedPools.length; i++) {
            if (votedPools[i] == pool) {
                return true;
            }
        }

        return false;
    }
}
