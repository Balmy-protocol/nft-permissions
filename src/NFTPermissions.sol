// SPDX-License-Identifier: MIT
pragma solidity >=0.8.8;

import { ERC721 } from "@solmate/tokens/ERC721.sol";
import { EIP712 } from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import { SignatureChecker } from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import { INFTPermissions } from "./interfaces/INFTPermissions.sol";
import { PermissionMath } from "./libraries/PermissionMath.sol";
import { PermissionHash } from "./libraries/PermissionHash.sol";

/**
 * @title NFT Permissions
 * @notice This contract allows devs to add authorization capabilities to their own contracts, with a very flexible permission system.
 *         The contract creates the concept of a "position", that underlying contracts can use to represent ownership. This could be
 *         ownership of funds or more complex ideas. Each position is represented by an NFT, that can be transferred by the owner.
 *         Whoever owns a position, has full permissions over the position. However, the owner can also grant/revoke specific permissions
 *         to other accounts. Permissions are represented by a number, so it's up to each dev to determine the values used to represent
 *         each permission in their system.
 *         Finally, the owner can grant permissions by interacting directly with the contract, but they can also be granted via signature.
 * @dev There are some technical details that devs should take into account when using this contract. For example:
 *      - Underlying contracts should not call _mint directly. Instead, they should call `_mintWithPermissions`
 *      - Underlying contracts should probably override `tokenURI` to provide the correct URI for their positions
 *      - Permissions are represented by a `uint8` but there can only be 192 different permisisons (0 <= permission ids < 192)
 *      - Permissions that were granted before or in the same block where the position was last transferred will be lost
 */
abstract contract NFTPermissions is ERC721, EIP712, INFTPermissions {
  type EncodedPermissions is uint192;
  error MustCallMintWithPermissions();

  struct AssignedPermissions {
    // We only support 192 different permissions (192 bits)
    EncodedPermissions permissions;
    // Block number when it was last updated (64 bits)
    uint64 lastUpdated;
  }

  struct PositionData {
    // The block number for when the position last changed ownership
    uint256 lastOwnershipChange;
    // A mapping of assigned permissions per operator
    mapping(address operator => AssignedPermissions permissions) assigned;
  }

  using PermissionMath for Permission[];
  using PermissionMath for EncodedPermissions;

  /// @inheritdoc INFTPermissions
  mapping(address owner => uint256 nextNonce) public nextNonce;

  mapping(uint256 positionId => PositionData data) private _positions;
  uint256 private _burnCounter;
  uint256 private _positionCounter;

  constructor(string memory _name, string memory _symbol, string memory _version) ERC721(_name, _symbol) EIP712(_name, _version) { }

  /// @inheritdoc INFTPermissions
  function DOMAIN_SEPARATOR() external view returns (bytes32) {
    return _domainSeparatorV4();
  }

  /// @inheritdoc INFTPermissions
  function totalSupply() external view returns (uint256) {
    return _positionCounter - _burnCounter;
  }

  /// @inheritdoc INFTPermissions
  function lastOwnershipChange(uint256 _positionId) external view returns (uint256 _blockNumber) {
    _blockNumber = _positions[_positionId].lastOwnershipChange;
  }

  /// @inheritdoc INFTPermissions
  function hasPermission(uint256 _positionId, address _account, Permission _permission) public view returns (bool) {
    if (ownerOf(_positionId) == _account) {
      return true;
    }
    PositionData storage _positionData = _positions[_positionId];
    AssignedPermissions memory _assigned = _positionData.assigned[_account];
    // If there was an ownership change after the permission was last updated, then the address doesn't have the permission
    return _assigned.permissions.hasPermission(_permission) && _positionData.lastOwnershipChange < _assigned.lastUpdated;
  }

  /// @inheritdoc INFTPermissions
  function modifyPermissions(PositionPermissions[] calldata _positionPermissions) external {
    for (uint256 i = 0; i < _positionPermissions.length;) {
      uint256 _positionId = _positionPermissions[i].positionId;
      if (msg.sender != ownerOf(_positionId)) revert NotOwner();
      _modify(_positionId, _positionPermissions[i].permissionSets);
      unchecked {
        i++;
      }
    }
  }

  /// @inheritdoc INFTPermissions
  function permissionPermit(PositionPermissions[] calldata _permissions, uint256 _deadline, bytes calldata _signature) external {
    // slither-disable-next-line timestamp
    if (block.timestamp > _deadline) revert ExpiredDeadline();

    // Note: will fail if _permissions is empty, and we are ok with it
    uint256 _firstPositionId = _permissions[0].positionId;
    address _owner = ownerOf(_firstPositionId);
    if (
      !SignatureChecker.isValidSignatureNow(_owner, _hashTypedDataV4(PermissionHash.hash(_permissions, nextNonce[_owner]++, _deadline)), _signature)
    ) {
      revert InvalidSignature();
    }
    _modify(_firstPositionId, _permissions[0].permissionSets);

    for (uint256 i = 1; i < _permissions.length;) {
      uint256 _positionId = _permissions[i].positionId;
      // Make sure that all positions belong to the same owner
      if (_owner != ownerOf(_positionId)) revert NotOwner();
      _modify(_positionId, _permissions[i].permissionSets);
      unchecked {
        i++;
      }
    }
  }

  /**
   * @notice Mints a new position with the assigned permissions
   * @dev Please note that this function does not emit an event with the new assigned permissions. It's up to each contract to then
   *      emit an event with the permissions, plus any other data they want
   * @param _owner The owner of the new position
   * @param _permissions The permissions to assign to the position
   * @return _positionId The new position's id
   */
  // slither-disable-next-line dead-code
  function _mintWithPermissions(address _owner, PermissionSet[] calldata _permissions) internal returns (uint256 _positionId) {
    unchecked {
      _positionId = ++_positionCounter;
    }
    super._mint(_owner, _positionId);
    _setPermissions(_positionId, _permissions);
  }

  // slither-disable-next-line dead-code
  function _assertHasPermission(uint256 _positionId, address _account, Permission _permission) internal view {
    if (!hasPermission(_positionId, _account, _permission)) {
      revert AccountWithoutPermission(_positionId, _account, _permission);
    }
  }

  modifier onlyWithPermission(uint256 _positionId, Permission _permission) {
    _assertHasPermission(_positionId, msg.sender, _permission);
    _;
  }

  function _modify(uint256 _positionId, PermissionSet[] calldata _permissions) private {
    _setPermissions(_positionId, _permissions);
    emit ModifiedPermissions(_positionId, _permissions);
  }

  function _setPermissions(uint256 _positionId, PermissionSet[] calldata _permissions) private {
    mapping(address operator => AssignedPermissions permissions) storage _assigned = _positions[_positionId].assigned;
    uint64 _blockNumber = uint64(block.number);
    for (uint256 i = 0; i < _permissions.length;) {
      PermissionSet memory _permissionSet = _permissions[i];
      if (_permissionSet.permissions.length == 0) {
        delete _assigned[_permissionSet.operator];
      } else {
        _assigned[_permissionSet.operator] = AssignedPermissions({ permissions: _permissionSet.permissions.encode(), lastUpdated: _blockNumber });
      }
      unchecked {
        i++;
      }
    }
  }

  /*//////////////////////////////////////////////////////////////
                          ERC721 OVERRIDES
  //////////////////////////////////////////////////////////////*/

  function transferFrom(address _from, address _to, uint256 _positionId) public override {
    _positions[_positionId].lastOwnershipChange = block.number;
    super.transferFrom(_from, _to, _positionId);
  }

  function _mint(address, uint256) internal pure override {
    // We don't want anyone calling this directly, so we override it and make it revert
    revert MustCallMintWithPermissions();
  }

  function _burn(uint256 _positionId) internal override {
    // Increase burn counter
    unchecked {
      _burnCounter++;
    }

    // When token is being burned, we can zero out this value
    _positions[_positionId].lastOwnershipChange = 0;

    super._burn(_positionId);
  }
}
