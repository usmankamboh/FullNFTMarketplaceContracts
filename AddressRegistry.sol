// SPDX-License-Identifier: MIT
pragma solidity 0.8.14;
import "./IERC165.sol";
import "./Ownable.sol";
contract AddressRegistry is Ownable {
    bytes4 private constant INTERFACE_ID_ERC721 = 0x80ac58cd;
    // Artion contract
    address public artion;
    // Auction contract
    address public auction;
    // Marketplace contract
    address public marketplace;
    // BundleMarketplace contract
    address public bundleMarketplace;
    // NFTFactory contract
    address public factory;
    // NFTFactoryPrivate contract
    address public privateFactory;
    // Factory contract
    address public artFactory;
    // FactoryPrivate contract
    address public privateArtFactory;
    // TokenRegistry contract
    address public tokenRegistry;
    // PriceFeed contract
    address public priceFeed;
    function updateArtion(address _artion) external onlyOwner {
        require(IERC165(_artion).supportsInterface(INTERFACE_ID_ERC721),"Not ERC721");
        artion = _artion;
    }
    function updateAuction(address _auction) external onlyOwner {
        auction = _auction;
    }
    function updateMarketplace(address _marketplace) external onlyOwner {
        marketplace = _marketplace;
    }
    function updateBundleMarketplace(address _bundleMarketplace) external onlyOwner {
        bundleMarketplace = _bundleMarketplace;
    }
    function updateNFTFactory(address _factory) external onlyOwner {
        factory = _factory;
    }
    function updateNFTFactoryPrivate(address _privateFactory)external onlyOwner{
        privateFactory = _privateFactory;
    }
    function updateArtFactory(address _artFactory) external onlyOwner {
        artFactory = _artFactory;
    }
    function updateArtFactoryPrivate(address _privateArtFactory) external onlyOwner{
        privateArtFactory = _privateArtFactory;
    }
    function updateTokenRegistry(address _tokenRegistry) external onlyOwner {
        tokenRegistry = _tokenRegistry;
    }
    function updatePriceFeed(address _priceFeed) external onlyOwner {
        priceFeed = _priceFeed;
    }
}
