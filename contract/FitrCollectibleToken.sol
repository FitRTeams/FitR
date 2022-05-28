// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// FIXME: Merge tokenId into OP
// FIXME: Try to override

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

contract FitrToken is ERC721URIStorage {
  using Counters for Counters.Counter;
  Counters.Counter private _tokenIds;
  VRFConsumerBaseV2 private _consumer;

  constructor(address vrfAddress) public ERC721("FitrToken", "FTR")    
  { 
    _admin = _msgSender();
    _consumer = VRFConsumerBaseV2(vrfAddress);
  }

  enum UsagePolicy { Illegal, UseBefore, NotUngrantable, ValidateOffline }
  // Priority: UseBefore
  // Deprioritized: NotUngrantable / ValidateOffline

  mapping(uint256 => mapping(address => UsagePolicy)) private _usagePolicies; // nft_id => {udid => enum UsagePolicy} // nft <-> Device
  mapping(uint256 => address) private _users; // nft_id => user_pbk // nft <-> Owner
  mapping(uint256 => uint256) private _genes; // nft_id => gene

  address private _admin;
  address private _vrf;

  function validatePermission(address signer, bytes32 hash, bytes memory signature)
    public view
    returns (bool)
  {
    require(_admin == _msgSender(), "FitrToken: Only admin can call this function.");
    require(SignatureChecker.isValidSignatureNow(signer, hash, signature), "FitrToken: Invalid permission");

    // FIXME: Authorization
  }

  function createAsset(address owner, address user, string memory url, uint32 requestId) // OP, IP, digest
    public
    returns (uint256)
  {
    require(_admin == _msgSender(), "FitrToken: Only admin can call this function.");

    _tokenIds.increment();

    uint256 tokenId = _tokenIds.current();
    _mint(owner, tokenId);
    _setTokenURI(tokenId, url);
    _users[tokenId] = user; // Assign owner
    uint256[] memory randomWords;
    _consumer.rawFulfillRandomWords(requestId, randomWords);
    _genes[tokenId] = randomWords[0];

    _approve(_msgSender(), tokenId); 
    return tokenId;

  }

  function append(uint256 tokenId, address owner, address user, address device, uint8 usagePolicy)
    public
  {
    require(_admin == _msgSender(), "FitrToken: Only admin can call this function.");
    require(_isApprovedOrOwner(_msgSender(), tokenId), "FitrToken: append caller is not owner nor approved");
    require(usagePolicy > 0 && usagePolicy <= uint8(UsagePolicy.ValidateOffline), "FitrToken: Usage policy out of range");

    _usagePolicies[tokenId][device] = UsagePolicy(usagePolicy);
  }

  function unappend(uint256 tokenId, address owner, address user, address device)
    public
  {
    require(_admin == _msgSender(), "FitrToken: Only admin can call this function.");
    require(_isApprovedOrOwner(_msgSender(), tokenId), "FitrToken: append caller is not owner nor approved");
    require(uint8(_usagePolicies[tokenId][device]) > 0, "FitrToken: unappend an nonexistent device");
  
    delete _usagePolicies[tokenId][device];
  }

  function changeOwner(address from, address to, uint256 tokenId)
    // FIXME: Authentication: IP0
    // FIXME: Authorization: IP0<->token
    // FIXME: Remove ownership key
    public  
  {
    require(_admin == _msgSender(), "FitrToken: Only admin can call this function.");
    require(_isApprovedOrOwner(_msgSender(), tokenId), "FitrToken: append caller is not owner nor approved");

    safeTransferFrom(from, to, tokenId);

    // clear all usage policies
    _clearUsagePolicies(tokenId);

    // clear user
    _users[tokenId] = address(0);

    // Reset approve
    _approve(_msgSender(), tokenId);
  }
  
  function usagePolicyOf(uint256 tokenId, address device) 
    public view
    returns (UsagePolicy)
  {
    require(uint8(_usagePolicies[tokenId][device]) > 0, "FitrToken: Get an nonexistent device");
    return _usagePolicies[tokenId][device];
  }

  function userOf(uint256 tokenId) 
    public view
    returns (address)
  {
    require(_exists(tokenId), "FitrToken: Nonexistent token");
    return _users[tokenId];
  }

  // todo: convert to event mode
  function latestTokenOf(address user)
    public view
    returns (uint256)
  {
    uint256 currentTokenId = _tokenIds.current();
    while (currentTokenId >= 0)
    {
      if (_users[currentTokenId] == user)
      {
        return currentTokenId;
      }
      currentTokenId--;
    }
  }

  function _clearUsagePolicies(uint256 tokenId)
    internal
  {
    require(_exists(tokenId), "FitrToken: Usage policy clear for nonexistent token");
    
    // todo: delete _usagePolicies[tokenId];
  }

  function _burn(uint256 tokenId)
    internal override
  {
    super._burn(tokenId);

    _users[tokenId] = address(0);
  }
}
