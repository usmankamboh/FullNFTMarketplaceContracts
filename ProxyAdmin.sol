// SPDX-License-Identifier: MIT
pragma solidity 0.8.14;
import "./Ownable.sol";
import "./AdminUpgradeabilityProxy.sol";
contract ProxyAdmin is Ownable {
  function getProxyImplementation(AdminUpgradeabilityProxy proxy) public view returns (address) {
    // We need to manually run the static call since the getter cannot be flagged as view
    // bytes4(keccak256("implementation()")) == 0x5c60da1b
    (bool success, bytes memory returndata) = address(proxy).staticcall(hex"5c60da1b");
    require(success);
    return abi.decode(returndata, (address));
  }
  function getProxyAdmin(AdminUpgradeabilityProxy proxy) public view returns (address) {
    // We need to manually run the static call since the getter cannot be flagged as view
    // bytes4(keccak256("admin()")) == 0xf851a440
    (bool success, bytes memory returndata) = address(proxy).staticcall(hex"f851a440");
    require(success);
    return abi.decode(returndata, (address));
  }
  function changeProxyAdmin(AdminUpgradeabilityProxy proxy, address newAdmin) public onlyOwner {
    proxy.changeAdmin(newAdmin);
  }
  function upgrade(AdminUpgradeabilityProxy proxy, address implementation) public onlyOwner {
    proxy.upgradeTo(implementation);
  }
  function upgradeAndCall(AdminUpgradeabilityProxy proxy, address implementation, bytes memory data) payable public onlyOwner {
    proxy.upgradeToAndCall{value: msg.value}(implementation, data);
  }
}