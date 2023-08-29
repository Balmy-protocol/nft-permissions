// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { PRBTest } from "@prb/test/PRBTest.sol";
import { StdUtils } from "forge-std/StdUtils.sol";
import { NFTPermissions, INFTPermissions } from "../../../src/NFTPermissions.sol";
import { PermissionMath } from "../../../src/libraries/PermissionMath.sol";
import { PermissionUtils as Utils } from "../../PermissionUtils.sol";

contract PermisisonMathTest is PRBTest, StdUtils {
  using PermissionMath for INFTPermissions.Permission[];
  using PermissionMath for NFTPermissions.EncodedPermissions;

  function testFuzz_encode_RevertWhen_PermissionIs192OrHigher(INFTPermissions.Permission _permission) public {
    _permission = _boundPermission(_permission, 192, type(uint8).max);
    INFTPermissions.Permission[] memory _permissions = Utils.permissions(_permission);
    vm.expectRevert(abi.encodeWithSelector(PermissionMath.InvalidPermission.selector, _permission));
    PermissionMath.encode(_permissions);
  }

  function testFuzz_encode_CanBeDecoded(
    INFTPermissions.Permission _permission1,
    INFTPermissions.Permission _permission2,
    INFTPermissions.Permission _permission3
  )
    public
  {
    _permission1 = _boundPermission(_permission1, 0, 191);
    _permission2 = _boundPermission(_permission2, 0, 191);
    vm.assume( // Forces permission3 to be different than other permissions
      INFTPermissions.Permission.unwrap(_permission1) != INFTPermissions.Permission.unwrap(_permission3)
        && INFTPermissions.Permission.unwrap(_permission2) != INFTPermissions.Permission.unwrap(_permission3)
    );

    INFTPermissions.Permission[] memory _permissions = Utils.permissions(_permission1, _permission2);
    NFTPermissions.EncodedPermissions _encoded = _permissions.encode();
    assertTrue(_encoded.hasPermission(_permission1));
    assertTrue(_encoded.hasPermission(_permission2));
    assertFalse(_encoded.hasPermission(_permission3));
  }

  function _boundPermission(INFTPermissions.Permission _permission, uint8 _min, uint8 _max) private view returns (INFTPermissions.Permission) {
    return INFTPermissions.Permission.wrap(uint8(bound(INFTPermissions.Permission.unwrap(_permission), _min, _max)));
  }
}
