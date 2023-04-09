// SPDX-License-Identifier: MIT
pragma solidity 0.8.14;
import "./IERC165.sol";
import "./IERC721.sol";
import "./IERC20.sol";
import "./SafeERC20.sol";
import "./SafeMath.sol";
import "./OwnableUpgradeable.sol";
import "./ReentrancyGuard.sol";
interface IAddressRegistry {
    function artion() external view returns (address);
    function bundleMarketplace() external view returns (address);
    function auction() external view returns (address);
    function factory() external view returns (address);
    function privateFactory() external view returns (address);
    function artFactory() external view returns (address);
    function privateArtFactory() external view returns (address);
    function tokenRegistry() external view returns (address);
    function priceFeed() external view returns (address);
}
interface IAuction {
    function auctions(address, uint256)external view returns (address,address,uint256,uint256,uint256,bool);
}
interface IBundleMarketplace {
    function validateItemSold(address,uint256,uint256) external;
}
interface INFTFactory {
    function exists(address) external view returns (bool);
}
interface ITokenRegistry {
    function enabled(address) external view returns (bool);
}
interface IPriceFeed {
    function wFTM() external view returns (address);
    function getPrice(address) external view returns (int256, uint8);
}

contract Marketplace is OwnableUpgradeable, ReentrancyGuard {
    using SafeMath for uint256;
    using AddressUpgradeable for address payable;
    using SafeERC20 for IERC20;
    // Events for the contract
    event ItemListed(address indexed owner,address indexed nft,uint256 tokenId,uint256 quantity,address payToken,uint256 pricePerItem,uint256 startingTime);
    event ItemSold(address indexed seller,address indexed buyer,address indexed nft,uint256 tokenId,uint256 quantity,
        address payToken,int256 unitPrice,uint256 pricePerItem);
    event ItemUpdated(address indexed owner,address indexed nft,uint256 tokenId,address payToken,uint256 newPrice);
    event ItemCanceled(address indexed owner,address indexed nft,uint256 tokenId);
    event OfferCreated(address indexed creator,address indexed nft,uint256 tokenId,uint256 quantity,address payToken,uint256 pricePerItem,uint256 deadline);
    event OfferCanceled(address indexed creator,address indexed nft,uint256 tokenId);
    event UpdatePlatformFee(uint16 platformFee);
    event UpdatePlatformFeeRecipient(address payable platformFeeRecipient);
    // Structure for listed items
    struct Listing {
        uint256 quantity;
        address payToken;
        uint256 pricePerItem;
        uint256 startingTime;
    }
    // Structure for offer
    struct Offer {
        IERC20 payToken;
        uint256 quantity;
        uint256 pricePerItem;
        uint256 deadline;
    }
    struct CollectionRoyalty {
        uint16 royalty;
        address creator;
        address feeRecipient;
    }
    bytes4 private constant INTERFACE_ID_ERC721 = 0x80ac58cd;
    bytes4 private constant INTERFACE_ID_ERC1155 = 0xd9b67a26;
    // NftAddress -> Token ID -> Minter
    mapping(address => mapping(uint256 => address)) public minters;
    // NftAddress -> Token ID -> Royalty
    mapping(address => mapping(uint256 => uint16)) public royalties;
    // NftAddress -> Token ID -> Owner -> Listing item
    mapping(address => mapping(uint256 => mapping(address => Listing)))public listings;
    // NftAddress -> Token ID -> Offerer -> Offer
    mapping(address => mapping(uint256 => mapping(address => Offer)))public offers;
    // Platform fee
    uint16 public platformFee;
    // Platform fee receipient
    address payable public feeReceipient;
    // NftAddress -> Royalty
    mapping(address => CollectionRoyalty) public collectionRoyalties;
    //  Address registry
    IAddressRegistry public addressRegistry;
    modifier onlyMarketplace() {
        require(address(addressRegistry.bundleMarketplace()) == _msgSender(),"sender must be bundle marketplace");
        _;
    }
    modifier isListed(address _nftAddress,uint256 _tokenId,address _owner) {
        Listing memory listing = listings[_nftAddress][_tokenId][_owner];
        require(listing.quantity > 0, "not listed item");
        _;
    }
    modifier notListed(address _nftAddress,uint256 _tokenId,address _owner) {
        Listing memory listing = listings[_nftAddress][_tokenId][_owner];
        require(listing.quantity == 0, "already listed");
        _;
    }
    modifier validListing(address _nftAddress,uint256 _tokenId,address _owner ) {
        Listing memory listedItem = listings[_nftAddress][_tokenId][_owner];
        _validOwner(_nftAddress, _tokenId, _owner, listedItem.quantity);
        require(_getNow() >= listedItem.startingTime, "item not buyable");
        _;
    }
    modifier offerExists(
        address _nftAddress,
        uint256 _tokenId,
        address _creator) {
        Offer memory offer = offers[_nftAddress][_tokenId][_creator];
        require(offer.quantity > 0 && offer.deadline > _getNow(),"offer not exists or expired");
        _;
    }
    modifier offerNotExists(address _nftAddress,uint256 _tokenId, address _creator) {
        Offer memory offer = offers[_nftAddress][_tokenId][_creator];
        require(offer.quantity == 0 || offer.deadline <= _getNow(),"offer already created");
        _;
    }
    // Contract initializer
    function initialize(address payable _feeRecipient, uint16 _platformFee) public initializer{
        platformFee = _platformFee;
        feeReceipient = _feeRecipient;
        __Ownable_init();

    }
    //  Method for listing NFT
    //  _nftAddress Address of NFT contract
    //  _tokenId Token ID of NFT
    //  _quantity token amount to list (needed for ERC-1155 NFTs, set as 1 for ERC-721)
    //  _payToken Paying token
    //  _pricePerItem sale price for each iteam
    //  _startingTime scheduling for a future sale
    function listItem(address _nftAddress,uint256 _tokenId,uint256 _quantity,address _payToken,uint256 _pricePerItem,
        uint256 _startingTime) external notListed(_nftAddress, _tokenId, _msgSender()) {
        if (IERC165(_nftAddress).supportsInterface(INTERFACE_ID_ERC721)) {
            IERC721 nft = IERC721(_nftAddress);
            require(nft.ownerOf(_tokenId) == _msgSender(), "not owning item");
            require(
                nft.isApprovedForAll(_msgSender(), address(this)),
                "item not approved"
            );
        } else {
            revert("invalid nft address");
        }
        _validPayToken(_payToken);
        listings[_nftAddress][_tokenId][_msgSender()] = Listing(_quantity,_payToken,_pricePerItem,_startingTime);
        emit ItemListed(_msgSender(),_nftAddress,_tokenId,_quantity,_payToken, _pricePerItem,_startingTime);
    }
    //  Method for canceling listed NFT
    function cancelListing(address _nftAddress, uint256 _tokenId)external nonReentrant isListed(_nftAddress, _tokenId, _msgSender()){
        _cancelListing(_nftAddress, _tokenId, _msgSender());
    }
    //  Method for updating listed NFT
    //  _nftAddress Address of NFT contract
    //  _tokenId Token ID of NFT
    //  _payToken payment token
    //  _newPrice New sale price for each iteam
    function updateListing(address _nftAddress,uint256 _tokenId,address _payToken,uint256 _newPrice) external nonReentrant isListed(_nftAddress, _tokenId, _msgSender()) {
        Listing storage listedItem = listings[_nftAddress][_tokenId][
            _msgSender()
        ];
        _validOwner(_nftAddress, _tokenId, _msgSender(), listedItem.quantity);
        _validPayToken(_payToken);
        listedItem.payToken = _payToken;
        listedItem.pricePerItem = _newPrice;
        emit ItemUpdated(_msgSender(),_nftAddress,_tokenId,_payToken,_newPrice);
    }
    //  Method for buying listed NFT
    //  _nftAddress NFT contract address
    //  _tokenId TokenId
    function buyItem(address _nftAddress,uint256 _tokenId,address _payToken,address _owner)
        external nonReentrant isListed(_nftAddress, _tokenId, _owner) validListing(_nftAddress, _tokenId, _owner){
        Listing memory listedItem = listings[_nftAddress][_tokenId][_owner];
        require(listedItem.payToken == _payToken, "invalid pay token");
        _buyItem(_nftAddress, _tokenId, _payToken, _owner);
    }
    function _buyItem(address _nftAddress,uint256 _tokenId,address _payToken,address _owner) private {
        Listing memory listedItem = listings[_nftAddress][_tokenId][_owner];
        uint256 price = listedItem.pricePerItem.mul(listedItem.quantity);
        uint256 feeAmount = price.mul(platformFee).div(1e3);
        IERC20(_payToken).safeTransferFrom(_msgSender(),feeReceipient,feeAmount);
        address minter = minters[_nftAddress][_tokenId];
        uint16 royalty = royalties[_nftAddress][_tokenId];
        if (minter != address(0) && royalty != 0) {
            uint256 royaltyFee = price.sub(feeAmount).mul(royalty).div(10000);
            IERC20(_payToken).safeTransferFrom(_msgSender(),minter,royaltyFee);
            feeAmount = feeAmount.add(royaltyFee);
        } else {
            minter = collectionRoyalties[_nftAddress].feeRecipient;
            royalty = collectionRoyalties[_nftAddress].royalty;
            if (minter != address(0) && royalty != 0) {
                uint256 royaltyFee = price.sub(feeAmount).mul(royalty).div(10000);
                IERC20(_payToken).safeTransferFrom(_msgSender(),minter,royaltyFee);
                feeAmount = feeAmount.add(royaltyFee);
            }
        }
        IERC20(_payToken).safeTransferFrom(_msgSender(),_owner,price.sub(feeAmount));
        // Transfer NFT to buyer
        if (IERC165(_nftAddress).supportsInterface(INTERFACE_ID_ERC721)) {
            IERC721(_nftAddress).safeTransferFrom(_owner,_msgSender(),_tokenId);
        }
        IBundleMarketplace(addressRegistry.bundleMarketplace()).validateItemSold(_nftAddress, _tokenId, listedItem.quantity);
        emit ItemSold(_owner,_msgSender(),_nftAddress,_tokenId,listedItem.quantity,
            _payToken,getPrice(_payToken),price.div(listedItem.quantity));
        delete (listings[_nftAddress][_tokenId][_owner]);
    }
    //  Method for offering item
    //  _nftAddress NFT contract address
    //  _tokenId TokenId
    //  _payToken Paying token
    //  _quantity Quantity of items
    //  _pricePerItem Price per item
    //  _deadline Offer expiration
    function createOffer(address _nftAddress,uint256 _tokenId,IERC20 _payToken,uint256 _quantity,uint256 _pricePerItem,
        uint256 _deadline) external offerNotExists(_nftAddress, _tokenId, _msgSender()) {
        require(IERC165(_nftAddress).supportsInterface(INTERFACE_ID_ERC721) ||
                IERC165(_nftAddress).supportsInterface(INTERFACE_ID_ERC1155),"invalid nft address");
        IAuction auction = IAuction(addressRegistry.auction());
        (, , , uint256 startTime, , bool resulted) = auction.auctions(_nftAddress,_tokenId);
        require(startTime == 0 || resulted == true,"cannot place an offer if auction is going on");
        require(_deadline > _getNow(), "invalid expiration");
        _validPayToken(address(_payToken));
        offers[_nftAddress][_tokenId][_msgSender()] = Offer(_payToken,_quantity,_pricePerItem, _deadline);
        emit OfferCreated(_msgSender(),_nftAddress,_tokenId,_quantity,address(_payToken),_pricePerItem,_deadline);
    }
    //  Method for canceling the offer
    //  _nftAddress NFT contract address
    //  _tokenId TokenId
    function cancelOffer(address _nftAddress, uint256 _tokenId)external offerExists(_nftAddress, _tokenId, _msgSender()){
        delete (offers[_nftAddress][_tokenId][_msgSender()]);
        emit OfferCanceled(_msgSender(), _nftAddress, _tokenId);
    }
    //  Method for accepting the offer
    //  _nftAddress NFT contract address
    //  _tokenId TokenId
    //  _creator Offer creator address
    function acceptOffer(address _nftAddress,uint256 _tokenId,address _creator) external nonReentrant offerExists(_nftAddress, _tokenId, _creator) {
        Offer memory offer = offers[_nftAddress][_tokenId][_creator];
        _validOwner(_nftAddress, _tokenId, _msgSender(), offer.quantity);
        uint256 price = offer.pricePerItem.mul(offer.quantity);
        uint256 feeAmount = price.mul(platformFee).div(1e3);
        uint256 royaltyFee;
        offer.payToken.safeTransferFrom(_creator, feeReceipient, feeAmount);
        address minter = minters[_nftAddress][_tokenId];
        uint16 royalty = royalties[_nftAddress][_tokenId];
        if (minter != address(0) && royalty != 0) {
            royaltyFee = price.sub(feeAmount).mul(royalty).div(10000);
            offer.payToken.safeTransferFrom(_creator, minter, royaltyFee);
            feeAmount = feeAmount.add(royaltyFee);
        } else {
            minter = collectionRoyalties[_nftAddress].feeRecipient;
            royalty = collectionRoyalties[_nftAddress].royalty;
            if (minter != address(0) && royalty != 0) {
                royaltyFee = price.sub(feeAmount).mul(royalty).div(10000);
                offer.payToken.safeTransferFrom(_creator, minter, royaltyFee);
                feeAmount = feeAmount.add(royaltyFee);
            }
        }
        offer.payToken.safeTransferFrom( _creator,_msgSender(),price.sub(feeAmount));
        // Transfer NFT to buyer
        if (IERC165(_nftAddress).supportsInterface(INTERFACE_ID_ERC721)) {
            IERC721(_nftAddress).safeTransferFrom(_msgSender(), _creator,_tokenId);
        } 
        IBundleMarketplace(addressRegistry.bundleMarketplace()).validateItemSold(_nftAddress, _tokenId, offer.quantity);
        emit ItemSold(_msgSender(),_creator,_nftAddress,_tokenId,offer.quantity,address(offer.payToken),getPrice(address(offer.payToken)),offer.pricePerItem);
        emit OfferCanceled(_creator, _nftAddress, _tokenId);
        delete (listings[_nftAddress][_tokenId][_msgSender()]);
        delete (offers[_nftAddress][_tokenId][_creator]);
    }
    //  Method for setting royalty
    //  _nftAddress NFT contract address
    //  _tokenId TokenId
    //  _royalty Royalty
    function registerRoyalty(address _nftAddress,uint256 _tokenId,uint16 _royalty) external {
        require(_royalty <= 10000, "invalid royalty");
        require(_isNFT(_nftAddress), "invalid nft address");
        _validOwner(_nftAddress, _tokenId, _msgSender(), 1);
        require(minters[_nftAddress][_tokenId] == address(0),"royalty already set");
        minters[_nftAddress][_tokenId] = _msgSender();
        royalties[_nftAddress][_tokenId] = _royalty;
    }
    //  Method for setting royalty
    //  _nftAddress NFT contract address
    //  _royalty Royalty
    function registerCollectionRoyalty(address _nftAddress,address _creator,uint16 _royalty,address _feeRecipient) external onlyOwner {
        require(_creator != address(0), "invalid creator address");
        require(_royalty <= 10000, "invalid royalty");
        require(_royalty == 0 || _feeRecipient != address(0),"invalid fee recipient address");
        require(!_isNFT(_nftAddress), "invalid nft address");
        if (collectionRoyalties[_nftAddress].creator == address(0)) {
            collectionRoyalties[_nftAddress] = CollectionRoyalty(_royalty,_creator, _feeRecipient);
        } else {
            CollectionRoyalty storage collectionRoyalty = collectionRoyalties[_nftAddress];
            collectionRoyalty.royalty = _royalty;
            collectionRoyalty.feeRecipient = _feeRecipient;
            collectionRoyalty.creator = _creator;
        }
    }
    function _isNFT(address _nftAddress) internal view returns (bool) {
        return addressRegistry.artion() == _nftAddress || INFTFactory(addressRegistry.factory()).exists(_nftAddress) ||
            INFTFactory(addressRegistry.privateFactory()).exists(_nftAddress) ||
            INFTFactory(addressRegistry.artFactory()).exists(_nftAddress) ||
            INFTFactory(addressRegistry.privateArtFactory()).exists(_nftAddress);
    }
    // Method for getting price for pay token
    // _payToken Paying token
    function getPrice(address _payToken) public view returns (int256) {
        int256 unitPrice;
        uint8 decimals;
        IPriceFeed priceFeed = IPriceFeed(addressRegistry.priceFeed());
        if (_payToken == address(0)) {
            (unitPrice, decimals) = priceFeed.getPrice(priceFeed.wFTM());
        } else {
            (unitPrice, decimals) = priceFeed.getPrice(_payToken);
        }
        if (decimals < 18) {
            unitPrice = unitPrice * (int256(10)**(18 - decimals));
        } else {
            unitPrice = unitPrice / (int256(10)**(decimals - 18));
        }
        return unitPrice;
    }
    // Method for updating platform fee
    // Only admin
    // _platformFee uint16 the platform fee to set
    function updatePlatformFee(uint16 _platformFee) external onlyOwner {
        platformFee = _platformFee;
        emit UpdatePlatformFee(_platformFee);
    }
    // Method for updating platform fee address
    // Only admin
    // _platformFeeRecipient payable address the address to sends the funds to
    function updatePlatformFeeRecipient(address payable _platformFeeRecipient)external onlyOwner{
        feeReceipient = _platformFeeRecipient;
        emit UpdatePlatformFeeRecipient(_platformFeeRecipient);
    }
    // Update AddressRegistry contract
    // Only admin
    function updateAddressRegistry(address _registry) external onlyOwner {
        addressRegistry = IAddressRegistry(_registry);
    }
    //  Validate and cancel listing
    //  Only bundle marketplace can access
    function validateItemSold(address _nftAddress,uint256 _tokenId,address _seller,address _buyer) external onlyMarketplace {
        Listing memory item = listings[_nftAddress][_tokenId][_seller];
        if (item.quantity > 0) {
            _cancelListing(_nftAddress, _tokenId, _seller);
        }
        delete (offers[_nftAddress][_tokenId][_buyer]);
        emit OfferCanceled(_buyer, _nftAddress, _tokenId);
    }
    // Internal and Private 
    function _getNow() internal view virtual returns (uint256) {
        return block.timestamp;
    }
    function _validPayToken(address _payToken) internal {
        require(_payToken == address(0) || (addressRegistry.tokenRegistry() != address(0) &&
                    ITokenRegistry(addressRegistry.tokenRegistry()).enabled(_payToken)),"invalid pay token");
    }
    function _validOwner(address _nftAddress,uint256 _tokenId,address _owner,uint256 quantity) internal {
        if (IERC165(_nftAddress).supportsInterface(INTERFACE_ID_ERC721)) {
            IERC721 nft = IERC721(_nftAddress);
            require(nft.ownerOf(_tokenId) == _owner, "not owning item");
        } else {
            revert("invalid nft address");
        }
    }
    function _cancelListing(address _nftAddress,uint256 _tokenId,address _owner) private {
        Listing memory listedItem = listings[_nftAddress][_tokenId][_owner];
        _validOwner(_nftAddress, _tokenId, _owner, listedItem.quantity);
        delete (listings[_nftAddress][_tokenId][_owner]);
        emit ItemCanceled(_owner, _nftAddress, _tokenId);
    }
}