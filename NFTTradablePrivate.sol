// SPDX-License-Identifier: MIT
pragma solidity 0.8.14;
import "./ERC721.sol";
import "./Ownable.sol";
contract NFTTradablePrivate is ERC721,Ownable {
    // Events of the contract
    event Minted(uint256 tokenId,address beneficiary,string tokenUri,address minter);
    event UpdatePlatformFee(uint256 platformFee);
    event UpdateFeeRecipient(address payable feeRecipient);
    using SafeMath for uint256;
    address auction;
    address marketplace;
    address bundleMarketplace;
    mapping (uint256 => string) private _tokenURIs;
    uint256 private _currentTokenId = 0;
    // Platform fee
    uint256 public platformFee;
    // Platform fee receipient
    address payable public feeReceipient;
    // Contract constructor
    constructor(string memory _name,string memory _symbol,address _auction,address _marketplace,address _bundleMarketplace,
        uint256 _platformFee,address payable _feeReceipient)ERC721(_name, _symbol) {
        auction = _auction;
        marketplace = _marketplace;
        bundleMarketplace = _bundleMarketplace;
        platformFee = _platformFee;
        feeReceipient = _feeReceipient;
    }
    function updatePlatformFee(uint256 _platformFee) external onlyOwner {
        platformFee = _platformFee;
        emit UpdatePlatformFee(_platformFee);
    }
    function updateFeeRecipient(address payable _feeReceipient)external onlyOwner{
        feeReceipient = _feeReceipient;
        emit UpdateFeeRecipient(_feeReceipient);
    }
    function mint(address _to, string calldata _tokenUri) external payable onlyOwner {
        require(msg.value >= platformFee, "Insufficient funds to mint.");
        uint256 newTokenId = _getNextTokenId();
        _safeMint(_to, newTokenId);
        _setTokenURI(newTokenId, _tokenUri);
        _incrementTokenId();
        // Send FTM fee to fee recipient
        (bool success,) = feeReceipient.call{value : msg.value}("");
        require(success, "Transfer failed");
        emit Minted(newTokenId, _to, _tokenUri, _msgSender());
    }
    function burn(uint256 _tokenId) external {
        address operator = _msgSender();
        require(ownerOf(_tokenId) == operator || isApproved(_tokenId, operator), "Only garment owner or approved");
        // Destroy token mappings
        _burn(_tokenId);
    }
    function _getNextTokenId() private view returns (uint256) {
        return _currentTokenId.add(1);
    }
    function _incrementTokenId() private {
        _currentTokenId++;
    }
    function isApproved(uint256 _tokenId, address _operator) public view returns (bool) {
        return isApprovedForAll(ownerOf(_tokenId), _operator) || getApproved(_tokenId) == _operator;
    }
    function isApprovedForAll(address owner, address operator)override public view returns (bool){
        // Whitelist auction, marketplace, bundle marketplace contracts for easy trading.
        if (auction == operator || marketplace == operator || bundleMarketplace == operator) {
            return true;
        }
        return super.isApprovedForAll(owner, operator);
    }
    function _isApprovedOrOwner(address spender, uint256 tokenId) override internal view returns (bool) {
        require(_exists(tokenId), "ERC721: operator query for nonexistent token");
        address owner = ERC721.ownerOf(tokenId);
        if (isApprovedForAll(owner, spender)) return true;
        return super._isApprovedOrOwner(spender, tokenId);
    }
    function _setTokenURI(uint256 tokenId, string memory _tokenURI) internal override virtual {
        require(_exists(tokenId), "ERC721Metadata: URI set of nonexistent token");
        _tokenURIs[tokenId] = _tokenURI;
    }
}