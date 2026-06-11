pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";
import {VERental} from "../src/VERental.sol";
import {VERentalMarketplace} from "../src/VERentalMarketplace.sol";

contract Deploy is Script {
    mapping(uint256 => address) private _ve;

    function run() public {
        initVe();

        uint256 chainId = block.chainid;
        vm.startBroadcast();
        // Deploy rental implementation first
        VERental rentalImpl = new VERental();
        VERentalMarketplace marketplace = new VERentalMarketplace(
            address(rentalImpl),
            _ve[chainId]
        );
        vm.stopBroadcast();

        string memory path = "deployments.json";
        vm.writeJson(
            vm.toString(address(marketplace)),
            path,
            string.concat(".", vm.toString(chainId))
        );
    }

    function initVe() public {
        _ve[4441] = address(0xF1B1c2f4E8FcD4aFCA0E608B1c7dB8b4e700154F);
        _ve[5042002] = address(0xF1B1c2f4E8FcD4aFCA0E608B1c7dB8b4e700154F);
    }
}
