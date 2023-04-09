// SPDX-License-Identifier: MIT
pragma solidity 0.8.14;
import "./Ownable.sol";
contract TokenRegistry is Ownable {
  // Events of the contract
  event TokenAdded(address token);
  event TokenRemoved(address token);
  // ERC20 Address -> Bool
  mapping(address => bool) public enabled;
  function add(address token) external onlyOwner {
    require(!enabled[token], "token already added");
    enabled[token] = true;
    emit TokenAdded(token);
  }
  function remove(address token) external onlyOwner {
    require(enabled[token], "token not exist");
    enabled[token] = false;
    emit TokenRemoved(token);
  }
}