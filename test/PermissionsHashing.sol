// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { INFTPermissions } from "../src/interfaces/INFTPermissions.sol";
import { PermissionHash } from "../src/libraries/PermissionHash.sol";

contract PermissionsHashing {
  function getMsgHash(
    INFTPermissions.PositionPermissions[] calldata _permissions,
    uint256 _nonce,
    uint256 _deadline,
    bytes32 _domainSeparator
  )
    public
    pure
    returns (bytes32)
  {
    bytes32 _structHash = PermissionHash.hash(_permissions, _nonce, _deadline);
    return keccak256(abi.encodePacked("\x19\x01", _domainSeparator, _structHash));
  }
}
