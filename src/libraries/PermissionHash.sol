// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import { INFTPermissions } from "../interfaces/INFTPermissions.sol";

library PermissionHash {
  using PermissionHash for INFTPermissions.PositionPermissions[];
  using PermissionHash for INFTPermissions.PositionPermissions;
  using PermissionHash for INFTPermissions.PermissionSet[];
  using PermissionHash for INFTPermissions.PermissionSet;
  using PermissionHash for INFTPermissions.Permission[];

  bytes32 public constant PERMISSION_PERMIT_TYPEHASH = keccak256(
    // solhint-disable-next-line max-line-length
    "PermissionPermit(PositionPermissions[] positions,uint256 nonce,uint256 deadline)PermissionSet(address operator,uint8[] permissions)PositionPermissions(uint256 positionId,PermissionSet[] permissionSets)"
  );
  bytes32 public constant PERMISSION_SET_TYPEHASH = keccak256("PermissionSet(address operator,uint8[] permissions)");
  bytes32 public constant POSITION_PERMISSIONS_TYPEHASH =
    keccak256("PositionPermissions(uint256 positionId,PermissionSet[] permissionSets)PermissionSet(address operator,uint8[] permissions)");

  function hash(INFTPermissions.PositionPermissions[] calldata _permissions, uint256 _nonce, uint256 _deadline) internal pure returns (bytes32) {
    return keccak256(abi.encode(PERMISSION_PERMIT_TYPEHASH, _permissions.hash(), _nonce, _deadline));
  }

  // slither-disable-next-line dead-code
  function hash(INFTPermissions.PositionPermissions[] calldata _permissions) internal pure returns (bytes32) {
    bytes32[] memory _hashes = new bytes32[](_permissions.length);
    for (uint256 i = 0; i < _permissions.length;) {
      _hashes[i] = _permissions[i].hash();
      unchecked {
        i++;
      }
    }
    return keccak256(abi.encodePacked(_hashes));
  }

  // slither-disable-next-line dead-code
  function hash(INFTPermissions.PositionPermissions calldata _permission) internal pure returns (bytes32) {
    return keccak256(abi.encode(POSITION_PERMISSIONS_TYPEHASH, _permission.positionId, _permission.permissionSets.hash()));
  }

  // slither-disable-next-line dead-code
  function hash(INFTPermissions.PermissionSet[] calldata _permissions) internal pure returns (bytes32) {
    bytes32[] memory _hashes = new bytes32[](_permissions.length);
    for (uint256 i = 0; i < _permissions.length;) {
      _hashes[i] = _permissions[i].hash();
      unchecked {
        i++;
      }
    }
    return keccak256(abi.encodePacked(_hashes));
  }

  // slither-disable-next-line dead-code
  function hash(INFTPermissions.PermissionSet calldata _permission) internal pure returns (bytes32) {
    return keccak256(abi.encode(PERMISSION_SET_TYPEHASH, _permission.operator, _permission.permissions.hash()));
  }

  // slither-disable-next-line dead-code
  function hash(INFTPermissions.Permission[] calldata _permissions) internal pure returns (bytes32) {
    return keccak256(abi.encodePacked(_permissions));
  }
}
