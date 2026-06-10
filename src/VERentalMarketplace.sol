pragma solidity ^0.8.0;

import {IVERentalMarketplace} from "./interfaces/IVERentalMarketplace.sol";
import {BaseTransfer} from "./base/BaseTransfer.sol";
import {IVERental} from "./interfaces/IVERental.sol";
import {IVotingEscrow} from "./interfaces/IVotingEscrow.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract VERentalMarketplace is IVERentalMarketplace, BaseTransfer, Ownable {
    address public rentalImpl;
    address public ve;
    address[] public allRentals;

    uint256 public nonce;

    constructor(
        address _rentalImpl,
        address _ve
    ) BaseTransfer() Ownable(msg.sender) {
        rentalImpl = _rentalImpl;
        ve = _ve;
    }

    function createRental(
        uint256 tokenId,
        address paymentToken,
        uint256 price,
        uint256 duration
    ) public returns (address rental) {
        address sender = msg.sender;

        nonce++;

        bytes32 salt = keccak256(abi.encodePacked(tokenId, nonce));
        rental = Clones.cloneDeterministic(rentalImpl, salt);

        IVERental(rental).initialize(
            sender,
            paymentToken,
            tokenId,
            price,
            duration
        );

        address escrow = IVERental(rental).escrow();
        IVotingEscrow(ve).safeTransferFrom(sender, escrow, tokenId);

        allRentals.push(rental);

        emit NewRental(rental, escrow, tokenId, paymentToken, price, duration);
    }

    function createRentals(
        uint256[] memory tokenIds,
        address[] memory paymentTokens,
        uint256[] memory prices,
        uint256[] memory durations
    ) external returns (address[] memory rentals) {
        require(
            tokenIds.length == paymentTokens.length &&
                paymentTokens.length == prices.length &&
                prices.length == durations.length,
            "LENGTHs"
        );

        rentals = new address[](tokenIds.length);

        for (uint i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            address paymentToken = paymentTokens[i];
            uint256 price = prices[i];
            uint256 duration = durations[i];

            address rental = createRental(
                tokenId,
                paymentToken,
                price,
                duration
            );
            rentals[i] = rental;
        }
    }

    function getAllRentals() external view returns (address[] memory) {
        return allRentals;
    }

    function withdrawAsset(
        address asset,
        address to,
        uint256 amount
    ) external onlyOwner {
        if (asset == address(0)) {
            _transferNative(to, amount);
        } else {
            _transferERC20(asset, to, amount);
        }
    }
}
