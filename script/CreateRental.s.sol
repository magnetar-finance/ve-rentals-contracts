import {Script, console} from "forge-std/Script.sol";
import {VERentalMarketplace} from "../src/VERentalMarketplace.sol";

contract CreateRental is Script {
    mapping(uint256 => address) public marketplaceByChainId;

    function run() public {
        initMarketplace();
        uint256 chainId = block.chainid;
        address marketplace = marketplaceByChainId[chainId];
        require(marketplace != address(0), "Marketplace not found for chainId");

        vm.startBroadcast();
        VERentalMarketplace rentalMarketplace = VERentalMarketplace(marketplace);
        rentalMarketplace.createRental(452, address(0x139D3ebda42572f2BbEE2C78DEC54DC14996dE15), 30000000000000000, 14 * 60 * 60 *24, 25);
        vm.stopBroadcast();
    }

    function initMarketplace() public {
        marketplaceByChainId[4441] = address(0x5F7Cb797F470858Be8909bf7e9EA7A9e87dbD118);
    }
}
