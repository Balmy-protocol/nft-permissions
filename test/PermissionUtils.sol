// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { INFTPermissions } from "../src/interfaces/INFTPermissions.sol";

library PermissionUtils {
  function buildPermissionSets(
    INFTPermissions.PermissionSet[] memory _permissionSet1,
    INFTPermissions.PermissionSet[] memory _permissionSet2
  )
    internal
    pure
    returns (INFTPermissions.PermissionSet[][] memory _permissionSets)
  {
    _permissionSets = new INFTPermissions.PermissionSet[][](2);
    _permissionSets[0] = _permissionSet1;
    _permissionSets[1] = _permissionSet2;
  }

  function buildEmptyPermissionSet() internal pure returns (INFTPermissions.PermissionSet[] memory _permissionSet) {
    _permissionSet = new INFTPermissions.PermissionSet[](0);
  }

  function buildPermissionSet(
    address _operator,
    INFTPermissions.Permission[] memory _permissions
  )
    internal
    pure
    returns (INFTPermissions.PermissionSet[] memory _permissionSet)
  {
    _permissionSet = new INFTPermissions.PermissionSet[](1);
    _permissionSet[0] = INFTPermissions.PermissionSet({ operator: _operator, permissions: _permissions });
  }

  function buildPermissionSet(
    address _operator1,
    INFTPermissions.Permission[] memory _permissions1,
    address _operator2,
    INFTPermissions.Permission[] memory _permissions2
  )
    internal
    pure
    returns (INFTPermissions.PermissionSet[] memory _permissionSet)
  {
    _permissionSet = new INFTPermissions.PermissionSet[](2);
    _permissionSet[0] = INFTPermissions.PermissionSet({ operator: _operator1, permissions: _permissions1 });
    _permissionSet[1] = INFTPermissions.PermissionSet({ operator: _operator2, permissions: _permissions2 });
  }

  function buildEmptyPositionPermissions() internal pure returns (INFTPermissions.PositionPermissions[] memory _permissions) {
    _permissions = new INFTPermissions.PositionPermissions[](0);
  }

  function buildPositionPermissions(
    uint256 _positionId,
    INFTPermissions.PermissionSet[] memory _permissionSets
  )
    internal
    pure
    returns (INFTPermissions.PositionPermissions[] memory _permissions)
  {
    _permissions = new INFTPermissions.PositionPermissions[](1);
    _permissions[0] = INFTPermissions.PositionPermissions({ positionId: _positionId, permissionSets: _permissionSets });
  }

  function buildPositionPermissions(
    uint256 _positionId1,
    INFTPermissions.PermissionSet[] memory _permissionSets1,
    uint256 _positionId2,
    INFTPermissions.PermissionSet[] memory _permissionSets2
  )
    internal
    pure
    returns (INFTPermissions.PositionPermissions[] memory _permissions)
  {
    _permissions = new INFTPermissions.PositionPermissions[](2);
    _permissions[0] = INFTPermissions.PositionPermissions({ positionId: _positionId1, permissionSets: _permissionSets1 });
    _permissions[1] = INFTPermissions.PositionPermissions({ positionId: _positionId2, permissionSets: _permissionSets2 });
  }

  function noPermissions() internal pure returns (INFTPermissions.Permission[] memory _permissions) {
    _permissions = new INFTPermissions.Permission[](0);
  }

  function permissions(INFTPermissions.Permission _permisison) internal pure returns (INFTPermissions.Permission[] memory _permissions) {
    _permissions = new INFTPermissions.Permission[](1);
    _permissions[0] = _permisison;
  }

  function permissions(
    INFTPermissions.Permission _permisison1,
    INFTPermissions.Permission _permisison2
  )
    internal
    pure
    returns (INFTPermissions.Permission[] memory _permissions)
  {
    _permissions = new INFTPermissions.Permission[](2);
    _permissions[0] = _permisison1;
    _permissions[1] = _permisison2;
  }

  function permissions(
    INFTPermissions.Permission _permisison1,
    INFTPermissions.Permission _permisison2,
    INFTPermissions.Permission _permisison3
  )
    internal
    pure
    returns (INFTPermissions.Permission[] memory _permissions)
  {
    _permissions = new INFTPermissions.Permission[](3);
    _permissions[0] = _permisison1;
    _permissions[1] = _permisison2;
    _permissions[2] = _permisison3;
  }
}
