// SPDX-License-Identifier: MIT
pragma solidity >=0.8.8;

interface INFTPermissions {
  type Permission is uint8;

  /// @notice A collection of permissions sets for a specific position
  struct PositionPermissions {
    // The id of the position
    uint256 positionId;
    // The permissions to assign to the position
    PermissionSet[] permissionSets;
  }

  /// @notice A set of permissions for a specific operator
  struct PermissionSet {
    // The address of the operator
    address operator;
    // The permissions given to the operator
    Permission[] permissions;
  }

  /**
   * @notice Emitted when permissions for a position are modified
   * @param positionId The id of the position
   * @param permissions The set of permissions that were updated
   */
  event ModifiedPermissions(uint256 positionId, PermissionSet[] permissions);

  /// @notice Thrown when a user tries to modify permissions for a position they do not own
  error NotOwner();

  /// @notice Thrown when a user tries to execute a permit with an expired deadline
  error ExpiredDeadline();

  /// @notice Thrown when a user tries to execute a permit with an invalid signature
  error InvalidSignature();

  /// @notice Thrown when a user tries perform an operation without permission
  error AccountWithoutPermission(uint256 positionId, address account, Permission permission);

  /**
   * @notice The domain separator used in the permit signature
   * @return The domain seperator used in encoding of permit signature
   */
  // solhint-disable-next-line func-name-mixedcase
  function DOMAIN_SEPARATOR() external view returns (bytes32);

  /**
   * @notice Returns the next nonce to use for a given user
   * @param account The address of the user
   * @return The next nonce to use
   */
  function nextNonce(address account) external view returns (uint256);

  /**
   * @notice Returns the block number where the ownership of the position last changed
   * @param positionId The position to check
   * @return The block number
   */
  function lastOwnershipChange(uint256 positionId) external view returns (uint256);

  /**
   * @notice Returns how many NFTs are currently tracked by this contract
   * @return How many of valid NFTs are tracked by this contract, where each one of
   *         them has an assigned and queryable owner not equal to the zero address
   */
  function totalSupply() external view returns (uint256);

  /**
   * @notice Returns whether the given account has the permission for the given position
   * @param positionId The id of the position to check
   * @param account The address of the user to check
   * @param permission The permission to check
   * @return Whether the user has the permission or not
   */
  function hasPermission(uint256 positionId, address account, Permission permission) external view returns (bool);

  /**
   * @notice Sets new permissions for the given positions
   * @dev Will revert if called by someone who is not the owner of all positions
   * @param positionPermissions A list of position permissions to set
   */
  function modifyPermissions(PositionPermissions[] calldata positionPermissions) external;

  /**
   * @notice Sets permissions via signature
   * @param permissions The permissions to set for the different positions
   * @param deadline The deadline timestamp by which the call must be mined for the approve to work
   * @param signature The signature
   */
  function permissionPermit(PositionPermissions[] calldata permissions, uint256 deadline, bytes calldata signature) external;
}
