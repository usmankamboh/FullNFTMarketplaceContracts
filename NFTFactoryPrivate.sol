// SPDX-License-Identifier: MIT
pragma solidity 0.8.14;
import "./Ownable.sol";
import "./NFTTradablePrivate.sol";
contract NFTFactoryPrivate is Ownable {
    // Events of the contract
    event ContractCreated(address creator, address nft);
    event ContractDisabled(address caller, address nft);
    //  auction contract address;
    address public auction;
    //  marketplace contract address;
    address public marketplace;
    //  bundle marketplace contract address;
    address public bundleMarketplace;
    //  NFT mint fee
    uint256 public mintFee;
    //  Platform fee for deploying new NFT contract
    uint256 public platformFee;
    //  Platform fee recipient
    address payable public feeRecipient;
    //  NFT Address => Bool
    mapping(address => bool) public exists;
    bytes4 private constant INTERFACE_ID_ERC721 = 0x80ac58cd;
    //  Contract constructor
    constructor(address _auction,address _marketplace,address _bundleMarketplace,uint256 _mintFee,address payable _feeRecipient,uint256 _platformFee){
        auction = _auction;
        marketplace = _marketplace;
        bundleMarketplace = _bundleMarketplace;
        mintFee = _mintFee;
        feeRecipient = _feeRecipient;
        platformFee = _platformFee;
    }
    //  Update auction contract
    //  Only admin
    //  _auction address the auction contract address to set
    function updateAuction(address _auction) external onlyOwner {
        auction = _auction;
    }
    //  Update marketplace contract
    //  Only admin
    //  _marketplace address the marketplace contract address to set
    function updateMarketplace(address _marketplace) external onlyOwner {
        marketplace = _marketplace;
    }
    //  Update bundle marketplace contract
    //  Only admin
    //  _bundleMarketplace address the bundle marketplace contract address to set
    function updateBundleMarketplace(address _bundleMarketplace)external onlyOwner{
        bundleMarketplace = _bundleMarketplace;
    }
    //  Update mint fee
    //  Only admin
    //  _mintFee uint256 the platform fee to set
    function updateMintFee(uint256 _mintFee) external onlyOwner {
        mintFee = _mintFee;
    }
    //  Update platform fee
    //  Only admin
    //  _platformFee uint256 the platform fee to set
    function updatePlatformFee(uint256 _platformFee) external onlyOwner {
        platformFee = _platformFee;
    }
    //  Method for updating platform fee address
    //  Only admin
    //  _feeRecipient payable address the address to sends the funds to
    function updateFeeRecipient(address payable _feeRecipient)external onlyOwner{
        feeRecipient = _feeRecipient;
    }
    //  Method for deploy new NFTTradable contract
    //  _name Name of NFT contract
    //  _symbol Symbol of NFT contract
    function createNFTContract(string memory _name, string memory _symbol)external payable returns (address){
        require(msg.value >= platformFee, "Insufficient funds.");
        (bool success,) = feeRecipient.call{value: msg.value}("");
        require(success, "Transfer failed");
        NFTTradablePrivate nft = new NFTTradablePrivate(_name,_symbol,auction,marketplace,bundleMarketplace,mintFee,feeRecipient);
        exists[address(nft)] = true;
        transferOwnership(_msgSender());
        emit ContractCreated(_msgSender(), address(nft));
        return address(nft);
    }
    //  Method for registering existing NFTTradable contract
    /// //   tokenContractAddress Address of NFT contract
    function registerTokenContract(address tokenContractAddress)external onlyOwner{
        require(!exists[tokenContractAddress], "NFT contract already registered");
        require(IERC165(tokenContractAddress).supportsInterface(INTERFACE_ID_ERC721), "Not an ERC721 contract");
        exists[tokenContractAddress] = true;
        emit ContractCreated(_msgSender(), tokenContractAddress);
    }
    //  Method for disabling existing NFTTradable contract
    //  tokenContractAddress Address of NFT contract
    function disableTokenContract(address tokenContractAddress)external onlyOwner{
        require(exists[tokenContractAddress], "NFT contract is not registered");
        exists[tokenContractAddress] = false;
        emit ContractDisabled(_msgSender(), tokenContractAddress);
    }
}