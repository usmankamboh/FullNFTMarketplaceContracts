// SPDX-License-Identifier: MIT
pragma solidity 0.8.14;
import "./Ownable.sol";
interface IAddressRegistry {
    function tokenRegistry() external view returns (address);
}
interface ITokenRegistry {
    function enabled(address) external returns (bool);
}
interface IOracle {
    function decimals() external view returns (uint8);
    function latestAnswer() external view returns (int256);
}
contract PriceFeed is Ownable {
    //  keeps track of oracles for each tokens
    mapping(address => address) public oracles;
    //  address registry contract
    address public addressRegistry;
    //  wrapped BNB contract
    address public wBNB;
    constructor(address _addressRegistry, address _wBNB){
        addressRegistry = _addressRegistry;
        wBNB = _wBNB;
    }
    function registerOracle(address _token, address _oracle)external onlyOwner{
        ITokenRegistry tokenRegistry = ITokenRegistry(IAddressRegistry(addressRegistry).tokenRegistry());
        require(tokenRegistry.enabled(_token), "invalid token");
        require(oracles[_token] == address(0), "oracle already set");
        oracles[_token] = _oracle;
    }
    function updateOracle(address _token, address _oracle) external onlyOwner {
        require(oracles[_token] != address(0), "oracle not set");
        oracles[_token] = _oracle;
    }
    function getPrice(address _token) external view returns (int256, uint8) {
        if (oracles[_token] == address(0)) {
            return (0, 0);
        }
        IOracle oracle = IOracle(oracles[_token]);
        return (oracle.latestAnswer(), oracle.decimals());
    }
    function updateAddressRegistry(address _addressRegistry)external onlyOwner{
        addressRegistry = _addressRegistry;
    }
}