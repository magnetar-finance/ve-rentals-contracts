pragma solidity ^0.8.0;

interface IVERentalMarketplace {
    event NewRental(
        address indexed rental,
        address indexed escrow,
        uint256 indexed tokenId,
        address paymentToken,
        uint256 price,
        uint256 duration
    );

    /// === State modifiers === ///
    function createRental(
        uint256 tokenId,
        address paymentToken,
        uint256 price,
        uint256 duration
    ) external returns (address);

    function createRentals(
        uint256[] memory tokenIds,
        address[] memory paymentTokens,
        uint256[] memory prices,
        uint256[] memory durations
    ) external returns (address[] memory);

    function allRentals(uint256 index) external view returns (address);

    function getAllRentals() external view returns (address[] memory);

    function ve() external view returns (address);

    function nonce() external view returns (uint256);
}
