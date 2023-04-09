// SPDX-License-Identifier: MIT
pragma solidity 0.8.14;
abstract contract Proxy {
    fallback () payable external {
        _fallback();
    }
    receive () payable external {
        _fallback();
    }
    function _implementation() internal virtual view returns (address);
    function _delegate(address implementation) internal {
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), implementation, 0, calldatasize(), 0, 0)
        // Copy the returned data.
            returndatacopy(0, 0, returndatasize())
            switch result
            // delegatecall returns 0 on error.
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }
    function _willFallback() internal virtual {
    }
    function _fallback() internal {
        _willFallback();
        _delegate(_implementation());
    }
}
library Address {
    function isContract(address account) internal view returns (bool) {
        uint256 size;
        // solhint-disable-next-line no-inline-assembly
        assembly { size := extcodesize(account) }
        return size > 0;
    }
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");
        // solhint-disable-next-line avoid-low-level-calls, avoid-call-value
        (bool success, ) = recipient.call{ value: amount }("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
      return functionCall(target, data, "Address: low-level call failed");
    }
    function functionCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
        return _functionCallWithValue(target, data, 0, errorMessage);
    }
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }
    function functionCallWithValue(address target, bytes memory data, uint256 value, string memory errorMessage) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        return _functionCallWithValue(target, data, value, errorMessage);
    }
    function _functionCallWithValue(address target, bytes memory data, uint256 weiValue, string memory errorMessage) private returns (bytes memory) {
        require(isContract(target), "Address: call to non-contract");
        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.call{ value: weiValue }(data);
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

                // solhint-disable-next-line no-inline-assembly
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }
}
contract UpgradeabilityProxy is Proxy {
    constructor(address _logic, bytes memory _data)payable {
        assert(IMPLEMENTATION_SLOT == bytes32(uint256(keccak256('eip1967.proxy.implementation')) - 1));
        _setImplementation(_logic);
        if(_data.length > 0) {
            (bool success,) = _logic.delegatecall(_data);
            require(success);
        }
    }
    event Upgraded(address indexed implementation);
    bytes32 internal constant IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
    function _implementation() internal override view returns (address impl) {
        bytes32 slot = IMPLEMENTATION_SLOT;
        assembly {
            impl := sload(slot)
        }
    }
    function _upgradeTo(address newImplementation) internal {
        _setImplementation(newImplementation);
        emit Upgraded(newImplementation);
    }
    function _setImplementation(address newImplementation) internal {
        require(Address.isContract(newImplementation), "Cannot set a proxy implementation to a non-contract address");

        bytes32 slot = IMPLEMENTATION_SLOT;

        assembly {
            sstore(slot, newImplementation)
        }
    }
}
contract AdminUpgradeabilityProxy is UpgradeabilityProxy {
    constructor(address _logic, address _Admin, bytes memory _data) UpgradeabilityProxy(_logic, _data) payable {
        assert(ADMIN_SLOT == bytes32(uint256(keccak256('eip1967.proxy.admin')) - 1));
        _setAdmin(_Admin);
    }
    event AdminChanged(address previousAdmin, address newAdmin);
    bytes32 internal constant ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;
    modifier ifAdmin() {
        if (msg.sender == _admin()) {
            _;
        } else {
            _fallback();
        }
    }
    function admin() external ifAdmin returns (address) {
        return _admin();
    }
    function implementation() external ifAdmin returns (address) {
        return _implementation();
    }
    function changeAdmin(address newAdmin) external ifAdmin {
        require(newAdmin != address(0), "Cannot change the admin of a proxy to the zero address");
        emit AdminChanged(_admin(), newAdmin);
        _setAdmin(newAdmin);
    }
    function upgradeTo(address newImplementation) external ifAdmin {
        _upgradeTo(newImplementation);
    }
    function upgradeToAndCall(address newImplementation, bytes calldata data) payable external ifAdmin {
        _upgradeTo(newImplementation);
        (bool success,) = newImplementation.delegatecall(data);
        require(success);
    }
    function _admin() internal view returns (address adm) {
        bytes32 slot = ADMIN_SLOT;
        assembly {
            adm := sload(slot)
        }
    }
    function _setAdmin(address newAdmin) internal {
        bytes32 slot = ADMIN_SLOT;
        assembly {
            sstore(slot, newAdmin)
        }
    }
    function _willFallback() internal override virtual {
        require(msg.sender != _admin(), "Cannot call fallback function from the proxy admin");
        super._willFallback();
    }
}