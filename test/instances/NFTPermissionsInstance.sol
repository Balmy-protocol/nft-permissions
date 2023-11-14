// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { NFTPermissions } from "../../src/NFTPermissions.sol";

contract NFTPermissionsInstance is NFTPermissions {
  constructor(string memory _name, string memory _symbol, string memory _version) NFTPermissions(_name, _symbol, _version) { }

  function mintWithPermissions(address _owner, PermissionSet[] calldata _permissions) external returns (uint256 _positionId) {
    return _mintWithPermissions(_owner, _permissions);
  }

  function assertHasPermission(uint256 _positionId, address _account, Permission _permission) external view {
    _assertHasPermission(_positionId, _account, _permission);
  }

  function burn(uint256 _positionid) external {
    _burn(_positionid);
  }
}
