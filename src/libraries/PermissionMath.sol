// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import { INFTPermissions } from "../interfaces/INFTPermissions.sol";
import { NFTPermissions } from "../NFTPermissions.sol";

/**
 * @title Permission Math library
 * @notice Provides functions to easily encode/decode between a set of permissions and their int representation
 */
library PermissionMath {
  /// @notice Thrown when trying to set a permission with an id that is too high
  error InvalidPermission(uint8 permission);

  /**
   * @notice Takes a list of permissions and returns the int representation of the set that contains them all
   * @param _permissions The list of permissions to encode
   * @return _encodedResult The uint representation
   */
  function encode(INFTPermissions.Permission[] memory _permissions) internal pure returns (NFTPermissions.EncodedPermissions) {
    uint256 _encodedResult;
    for (uint256 i = 0; i < _permissions.length;) {
      uint8 _permission = INFTPermissions.Permission.unwrap(_permissions[i]);
      if (_permission >= 192) {
        revert InvalidPermission(_permission);
      }
      _encodedResult |= 1 << _permission;
      unchecked {
        i++;
      }
    }
    return NFTPermissions.EncodedPermissions.wrap(uint192(_encodedResult));
  }

  /**
   * @notice Takes an int representation of a set of permissions, and returns whether it contains the given permission
   * @param _encoded The int representation
   * @param _permission The permission to check for
   * @return Whether the representation contains the given permission
   */
  function hasPermission(NFTPermissions.EncodedPermissions _encoded, INFTPermissions.Permission _permission) internal pure returns (bool) {
    uint256 _bitMask = 1 << INFTPermissions.Permission.unwrap(_permission);
    return (NFTPermissions.EncodedPermissions.unwrap(_encoded) & _bitMask) != 0;
  }
}
