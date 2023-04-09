// SPDX-License-Identifier: MIT
pragma solidity 0.8.14;
import "./ERC721.sol";
import "./Ownable.sol";
contract NFT is ERC721("USMAN", "USK"), Ownable {
    // Events of the contract
    event Minted(uint256 tokenId,address beneficiary,string tokenUri,address minter);
    event UpdatePlatformFee(uint256 platformFee);
    event UpdatePlatformFeeRecipient(address payable platformFeeRecipient);
    using SafeMath for uint256;
    // current max tokenId
    uint256 public tokenIdPointer;
    // TokenID -> Creator address
    mapping(uint256 => address) public creators;
    // Platform fee
    uint256 public platformFee;
    // Platform fee receipient
    address payable public feeReceipient;
    // Contract constructor
    constructor(address payable _feeRecipient,uint256 _platformFee){
        platformFee = _platformFee;
        feeReceipient = _feeRecipient;
    }
    function mint(address _beneficiary, string calldata _tokenUri) external payable returns (uint256) {
        require(msg.value >= platformFee, "Insufficient funds to mint.");
        // Valid args
        _assertMintingParamsValid(_tokenUri, _msgSender());
        tokenIdPointer = tokenIdPointer.add(1);
        uint256 tokenId = tokenIdPointer;
        // Mint token and set token URI
        _safeMint(_beneficiary, tokenId);
        _setTokenURI(tokenId, _tokenUri);
        // Send FTM fee to fee recipient
        feeReceipient.transfer(msg.value);
        // Associate garment designer
        creators[tokenId] = _msgSender();
        emit Minted(tokenId, _beneficiary, _tokenUri, _msgSender());
        return tokenId;
    }
    function burn(uint256 _tokenId) external {
        address operator = _msgSender();
        require(ownerOf(_tokenId) == operator || isApproved(_tokenId, operator), "Only garment owner or approved");
        // Destroy token mappings
        _burn(_tokenId);
        // Clean up designer mapping
        delete creators[_tokenId];
    }
    function _extractIncomingTokenId() internal pure returns (uint256) {
        // Extract out the embedded token ID from the sender
        uint256 _receiverTokenId;
        uint256 _index = msg.data.length - 32;
        assembly {_receiverTokenId := calldataload(_index)}
        return _receiverTokenId;
    }
    function exists(uint256 _tokenId) external view returns (bool) {
        return _exists(_tokenId);
    }
    function isApproved(uint256 _tokenId, address _operator) public view returns (bool) {
        return isApprovedForAll(ownerOf(_tokenId), _operator) || getApproved(_tokenId) == _operator;
    }
    function updatePlatformFee(uint256 _platformFee) external onlyOwner {
        platformFee = _platformFee;
        emit UpdatePlatformFee(_platformFee);
    }
    function updatePlatformFeeRecipient(address payable _platformFeeRecipient) external onlyOwner {
        feeReceipient = _platformFeeRecipient;
        emit UpdatePlatformFeeRecipient(_platformFeeRecipient);
    }
    function _assertMintingParamsValid(string calldata _tokenUri, address _designer) pure internal {
        require(bytes(_tokenUri).length > 0, "_assertMintingParamsValid: Token URI is empty");
        require(_designer != address(0), "_assertMintingParamsValid: Designer is zero address");
    }
}