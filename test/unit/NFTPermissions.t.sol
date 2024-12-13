// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { PRBTest } from "@prb/test/PRBTest.sol";
import { StdUtils } from "forge-std/StdUtils.sol";
import { IERC1271 } from "@openzeppelin/contracts/interfaces/IERC1271.sol";
import { INFTPermissions } from "../../src/interfaces/INFTPermissions.sol";
import { NFTPermissionsInstance } from "../instances/NFTPermissionsInstance.sol";
import { PermissionUtils as Utils } from "../PermissionUtils.sol";
import { PermissionsHashing } from "../PermissionsHashing.sol";

contract NFTPermissionsTest is PRBTest, StdUtils {
  using InternalUtils for INFTPermissions.Permission[];

  event ModifiedPermissions(uint256 positionId, INFTPermissions.PermissionSet[] permissions);

  INFTPermissions.Permission private constant PERMISSION_1 = INFTPermissions.Permission.wrap(0);
  INFTPermissions.Permission private constant PERMISSION_2 = INFTPermissions.Permission.wrap(10);
  INFTPermissions.Permission private constant PERMISSION_3 = INFTPermissions.Permission.wrap(20);
  uint256 private ownerPK;
  address private owner;
  address private operator1 = address(2);
  address private operator2 = address(3);
  NFTPermissionsInstance private nftPermissions;
  PermissionsHashing private hashing;

  function setUp() public virtual {
    ownerPK = 0x12341234;
    owner = vm.addr(ownerPK);
    hashing = new PermissionsHashing();
    nftPermissions = new NFTPermissionsInstance("Name", "SYM", "1");
  }

  function test_constructor() public {
    assertEq(nftPermissions.name(), "Name");
    assertEq(nftPermissions.symbol(), "SYM");
    bytes32 _typeHash = keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 _expectedDomainSeparator = keccak256(abi.encode(_typeHash, keccak256("Name"), keccak256("1"), block.chainid, address(nftPermissions)));
    assertEq(nftPermissions.DOMAIN_SEPARATOR(), _expectedDomainSeparator);
  }

  function test_hasPermission_PermissionsAreLostAfterATransfer() public {
    address _newOwner = address(10);
    INFTPermissions.PermissionSet[] memory _permissionSet = new INFTPermissions.PermissionSet[](1);
    _permissionSet[0] = INFTPermissions.PermissionSet({ operator: operator1, permissions: Utils.permissions(PERMISSION_1) });

    uint256 _positionId = nftPermissions.mintWithPermissions(owner, _permissionSet);
    assertFalse(nftPermissions.hasPermission(_positionId, _newOwner, PERMISSION_1));
    assertTrue(nftPermissions.hasPermission(_positionId, owner, PERMISSION_1));
    assertTrue(nftPermissions.hasPermission(_positionId, operator1, PERMISSION_1));

    // Advance block
    uint256 _blockNumber = block.number + 1;
    vm.roll(_blockNumber);

    // Transfer position
    vm.prank(owner);
    nftPermissions.transferFrom(owner, _newOwner, _positionId);

    assertTrue(nftPermissions.hasPermission(_positionId, _newOwner, PERMISSION_1));
    assertFalse(nftPermissions.hasPermission(_positionId, owner, PERMISSION_1));
    assertFalse(nftPermissions.hasPermission(_positionId, operator1, PERMISSION_1));
    assertEq(nftPermissions.lastOwnershipChange(_positionId), _blockNumber);
  }

  function test_totalSupply_IsCorrectThroughMintsAndBurns() public {
    uint256 _positionId1 = nftPermissions.mintWithPermissions(owner, new INFTPermissions.PermissionSet[](0));
    uint256 _positionId2 = nftPermissions.mintWithPermissions(owner, new INFTPermissions.PermissionSet[](0));
    assertEq(nftPermissions.totalSupply(), 2);

    nftPermissions.burn(_positionId2);
    assertEq(nftPermissions.totalSupply(), 1);

    uint256 _positionId3 = nftPermissions.mintWithPermissions(owner, new INFTPermissions.PermissionSet[](0));
    assertEq(nftPermissions.totalSupply(), 2);

    nftPermissions.burn(_positionId1);
    assertEq(nftPermissions.totalSupply(), 1);

    nftPermissions.burn(_positionId3);
    assertEq(nftPermissions.totalSupply(), 0);
  }

  function test_modifyPermissions_RevertWhen_NotOwner() public {
    uint256 _positionId = nftPermissions.mintWithPermissions(owner, Utils.buildEmptyPermissionSet());

    vm.expectRevert(abi.encodeWithSelector(INFTPermissions.NotOwner.selector));

    vm.prank(operator1);
    nftPermissions.modifyPermissions(
      Utils.buildPositionPermissions(_positionId, Utils.buildPermissionSet(operator1, Utils.permissions(PERMISSION_1)))
    );
  }

  function test_modifyPermissions_PermissionsAreAddedForNewOperators() public {
    _modifyTest({
      _initial1: Utils.buildEmptyPermissionSet(),
      _modify1: Utils.buildPermissionSet(operator1, Utils.permissions(PERMISSION_1)),
      _expected1: Utils.buildPermissionSet(operator1, Utils.permissions(PERMISSION_1), operator2, Utils.noPermissions()),
      _initial2: Utils.buildPermissionSet(operator1, Utils.permissions(PERMISSION_1)),
      _modify2: Utils.buildPermissionSet(operator2, Utils.permissions(PERMISSION_2)),
      _expected2: Utils.buildPermissionSet(operator1, Utils.permissions(PERMISSION_1), operator2, Utils.permissions(PERMISSION_2))
    });
  }

  function test_modifyPermissions_PermissionsAreModifiedForExistingOperators() public {
    _modifyTest({
      _initial1: Utils.buildPermissionSet(operator1, Utils.permissions(PERMISSION_1)),
      _modify1: Utils.buildPermissionSet(operator1, Utils.permissions(PERMISSION_2)),
      _expected1: Utils.buildPermissionSet(operator1, Utils.permissions(PERMISSION_2), operator2, Utils.noPermissions()),
      _initial2: Utils.buildPermissionSet(operator1, Utils.permissions(PERMISSION_1)),
      _modify2: Utils.buildPermissionSet(operator1, Utils.permissions(PERMISSION_1, PERMISSION_2)),
      _expected2: Utils.buildPermissionSet(operator1, Utils.permissions(PERMISSION_1, PERMISSION_2), operator2, Utils.noPermissions())
    });
  }

  function test_modifyPermissions_PermissionsAreRemovedForExistingOperators() public {
    _modifyTest({
      _initial1: Utils.buildPermissionSet(operator1, Utils.permissions(PERMISSION_1), operator2, Utils.permissions(PERMISSION_1)),
      _modify1: Utils.buildPermissionSet(operator1, Utils.noPermissions()),
      _expected1: Utils.buildPermissionSet(operator1, Utils.noPermissions(), operator2, Utils.permissions(PERMISSION_1)),
      _initial2: Utils.buildPermissionSet(operator1, Utils.permissions(PERMISSION_1, PERMISSION_2), operator2, Utils.permissions(PERMISSION_1)),
      _modify2: Utils.buildPermissionSet(operator1, Utils.noPermissions(), operator2, Utils.noPermissions()),
      _expected2: Utils.buildPermissionSet(operator1, Utils.noPermissions(), operator2, Utils.noPermissions())
    });
  }

  function test_modifyPermissions_RevertWhen_ModifiedOnTheSameBlockAsTransfer() public {
    address newOwner = address(10);

    uint256 positionId = nftPermissions.mintWithPermissions(owner, Utils.buildEmptyPermissionSet());
    vm.prank(owner);
    nftPermissions.transferFrom(owner, newOwner, positionId);

    INFTPermissions.PositionPermissions[] memory _permissions =
      Utils.buildPositionPermissions(positionId, Utils.buildPermissionSet(operator1, Utils.permissions(PERMISSION_1)));
    vm.expectRevert(abi.encodeWithSelector(INFTPermissions.CantModifyPermissionsOnTheSameBlockPositionWasTransferred.selector));
    vm.prank(newOwner);
    nftPermissions.modifyPermissions(_permissions);
  }

  function test_modifyPermissions_WorkInTheNextBlockAfterTransfer() public {
    address newOwner = address(10);

    uint256 positionId = nftPermissions.mintWithPermissions(owner, Utils.buildEmptyPermissionSet());
    vm.prank(owner);
    nftPermissions.transferFrom(owner, newOwner, positionId);

    vm.roll(block.number + 1);
    vm.prank(newOwner);
    INFTPermissions.PositionPermissions[] memory _permissions =
      Utils.buildPositionPermissions(positionId, Utils.buildPermissionSet(operator1, Utils.permissions(PERMISSION_1)));
    nftPermissions.modifyPermissions(_permissions);
    _checkPermissions(_permissions);
  }

  function test_permissionPermit_RevertWhen_DeadlineHasExpired() public {
    vm.expectRevert(abi.encodeWithSelector(INFTPermissions.ExpiredDeadline.selector));

    nftPermissions.permissionPermit(Utils.buildEmptyPositionPermissions(), block.timestamp - 1, "");
  }

  function test_permissionPermit_SettingOnePermission() public {
    uint256 _positionId = nftPermissions.mintWithPermissions(owner, Utils.buildEmptyPermissionSet());
    INFTPermissions.PositionPermissions[] memory _permissions =
      Utils.buildPositionPermissions(_positionId, Utils.buildPermissionSet(operator1, Utils.permissions(PERMISSION_1)));
    _permissionPermitTestEOA(_permissions);
  }

  function test_permissionPermit_SettingTwoPermissions() public {
    uint256 _positionId1 = nftPermissions.mintWithPermissions(owner, Utils.buildEmptyPermissionSet());
    uint256 _positionId2 = nftPermissions.mintWithPermissions(owner, Utils.buildEmptyPermissionSet());
    INFTPermissions.PositionPermissions[] memory _permissions = Utils.buildPositionPermissions(
      _positionId1,
      Utils.buildPermissionSet(operator1, Utils.permissions(PERMISSION_1, PERMISSION_2)),
      _positionId2,
      Utils.buildPermissionSet(operator2, Utils.permissions(PERMISSION_3, PERMISSION_2))
    );
    _permissionPermitTestEOA(_permissions);
  }

  function test_permissionPermit_SettingAllPermissions() public {
    uint256 _positionId1 = nftPermissions.mintWithPermissions(owner, Utils.buildEmptyPermissionSet());
    uint256 _positionId2 = nftPermissions.mintWithPermissions(owner, Utils.buildEmptyPermissionSet());
    INFTPermissions.PositionPermissions[] memory _permissions = Utils.buildPositionPermissions(
      _positionId1,
      Utils.buildPermissionSet(operator1, Utils.permissions(PERMISSION_1, PERMISSION_2, PERMISSION_3)),
      _positionId2,
      Utils.buildPermissionSet(operator2, Utils.permissions(PERMISSION_3, PERMISSION_1, PERMISSION_2))
    );
    _permissionPermitTestEOA(_permissions);
  }

  function test_permissionPermit_UsingERC1271() public {
    ERC1271Contract _smartContractOwner = new ERC1271Contract();
    uint256 _positionId = nftPermissions.mintWithPermissions(address(_smartContractOwner), Utils.buildEmptyPermissionSet());

    uint256 _deadline = type(uint256).max;
    INFTPermissions.PositionPermissions[] memory _permissions =
      Utils.buildPositionPermissions(_positionId, Utils.buildPermissionSet(operator1, Utils.permissions(PERMISSION_1, PERMISSION_2)));
    bytes32 _msgHash = hashing.getMsgHash(_permissions, 0, _deadline, nftPermissions.DOMAIN_SEPARATOR());

    _executePermitAndCheck(address(_smartContractOwner), _permissions, _deadline, abi.encode(_msgHash));
  }

  function test_permissionPermit_RevertWhen_UsingERC1271WithInvalidSignature() public {
    ERC1271Contract _smartContractOwner = new ERC1271Contract();
    uint256 _positionId = nftPermissions.mintWithPermissions(address(_smartContractOwner), Utils.buildEmptyPermissionSet());

    uint256 _deadline = type(uint256).max;
    INFTPermissions.PositionPermissions[] memory _permissions =
      Utils.buildPositionPermissions(_positionId, Utils.buildPermissionSet(operator1, Utils.permissions(PERMISSION_1, PERMISSION_2)));

    vm.expectRevert(abi.encodeWithSelector(INFTPermissions.InvalidSignature.selector));
    nftPermissions.permissionPermit(_permissions, _deadline, "");
  }

  function test_mintWithPermissions_PositionIsCreatedCorrectly() public {
    INFTPermissions.PermissionSet[] memory _permissionSet = new INFTPermissions.PermissionSet[](1);
    _permissionSet[0] = INFTPermissions.PermissionSet({ operator: operator1, permissions: Utils.permissions(PERMISSION_1) });

    uint256 _positionId = nftPermissions.mintWithPermissions(owner, _permissionSet);

    assertEq(_positionId, 1);
    assertEq(nftPermissions.ownerOf(_positionId), owner);
    assertEq(nftPermissions.balanceOf(owner), 1);
    assertEq(nftPermissions.totalSupply(), 1);
    // Owner should have all permissions assigned
    assertTrue(nftPermissions.hasPermission(_positionId, owner, PERMISSION_1));
    assertTrue(nftPermissions.hasPermission(_positionId, owner, PERMISSION_2));
    // Operator should only have PERMISSION_1 assigned
    assertTrue(nftPermissions.hasPermission(_positionId, operator1, PERMISSION_1));
    assertFalse(nftPermissions.hasPermission(_positionId, operator1, PERMISSION_2));
  }

  function test_mintWithPermissions_PositionsAreCreatedSequentially() public {
    INFTPermissions.PermissionSet[] memory _permissionSet = new INFTPermissions.PermissionSet[](0);
    uint256 _positionId1 = nftPermissions.mintWithPermissions(owner, _permissionSet);
    uint256 _positionId2 = nftPermissions.mintWithPermissions(owner, _permissionSet);
    uint256 _positionId3 = nftPermissions.mintWithPermissions(owner, _permissionSet);
    assertEq(_positionId1, 1);
    assertEq(_positionId2, 2);
    assertEq(_positionId3, 3);
    assertEq(nftPermissions.balanceOf(owner), 3);
    assertEq(nftPermissions.totalSupply(), 3);
  }

  function test_assertAccountHasPermission_RevertWhen_AccountDoesntHaveIt() public {
    uint256 _positionId = nftPermissions.mintWithPermissions(owner, Utils.buildEmptyPermissionSet());

    vm.expectRevert(abi.encodeWithSelector(INFTPermissions.AccountWithoutPermission.selector, _positionId, operator1, PERMISSION_1));
    nftPermissions.assertHasPermission(_positionId, operator1, PERMISSION_1);
  }

  function test_assertAccountHasPermission_IsNoopWhenAccountHasPermission() public {
    uint256 _positionId = nftPermissions.mintWithPermissions(owner, Utils.buildEmptyPermissionSet());
    nftPermissions.assertHasPermission(_positionId, owner, PERMISSION_1);
  }

  function _modifyTest(
    INFTPermissions.PermissionSet[] memory _initial1,
    INFTPermissions.PermissionSet[] memory _initial2,
    INFTPermissions.PermissionSet[] memory _modify1,
    INFTPermissions.PermissionSet[] memory _modify2,
    INFTPermissions.PermissionSet[] memory _expected1,
    INFTPermissions.PermissionSet[] memory _expected2
  )
    internal
  {
    // Create positions
    uint256 _positionId1 = nftPermissions.mintWithPermissions(owner, _initial1);
    uint256 _positionId2 = nftPermissions.mintWithPermissions(owner, _initial2);

    // Expect emits
    vm.expectEmit();
    emit ModifiedPermissions(_positionId1, _modify1);
    vm.expectEmit();
    emit ModifiedPermissions(_positionId2, _modify2);

    // Modify permissions
    INFTPermissions.PositionPermissions[] memory _permissions = new INFTPermissions.PositionPermissions[](2);
    _permissions[0] = INFTPermissions.PositionPermissions({ positionId: _positionId1, permissionSets: _modify1 });
    _permissions[1] = INFTPermissions.PositionPermissions({ positionId: _positionId2, permissionSets: _modify2 });
    vm.prank(owner);
    nftPermissions.modifyPermissions(_permissions);

    // Make sure everything worked as expected
    _checkPermissions(_positionId1, _expected1);
    _checkPermissions(_positionId2, _expected2);
  }

  function _permissionPermitTestEOA(INFTPermissions.PositionPermissions[] memory _permissions) internal {
    uint256 _deadline = type(uint256).max;
    bytes32 _msgHash = hashing.getMsgHash(_permissions, 0, _deadline, nftPermissions.DOMAIN_SEPARATOR());
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPK, _msgHash);
    bytes memory _sig = bytes.concat(r, s, bytes1(v));

    _executePermitAndCheck(owner, _permissions, _deadline, _sig);
  }

  function _executePermitAndCheck(
    address _owner,
    INFTPermissions.PositionPermissions[] memory _permissions,
    uint256 _deadline,
    bytes memory _signature
  )
    internal
  {
    // Prepare to check events
    for (uint256 i; i < _permissions.length; i++) {
      vm.expectEmit();
      emit ModifiedPermissions(_permissions[i].positionId, _permissions[i].permissionSets);
    }

    nftPermissions.permissionPermit(_permissions, _deadline, _signature);

    // Check permissions were granted
    _checkPermissions(_permissions);

    // Check nonce is increased
    assertEq(nftPermissions.nextNonce(_owner), 1);
  }

  function _checkPermissions(INFTPermissions.PositionPermissions[] memory _permissions) internal {
    for (uint256 i; i < _permissions.length; i++) {
      _checkPermissions(_permissions[i].positionId, _permissions[i].permissionSets);
    }
  }

  function _checkPermissions(uint256 _positionId, INFTPermissions.PermissionSet[] memory _expected) internal {
    for (uint256 i; i < _expected.length; i++) {
      bool _shouldHavePermission1 = _expected[i].permissions.contains(PERMISSION_1);
      bool _shouldHavePermission2 = _expected[i].permissions.contains(PERMISSION_2);
      bool _shouldHavePermission3 = _expected[i].permissions.contains(PERMISSION_3);
      assertEq(nftPermissions.hasPermission(_positionId, _expected[i].operator, PERMISSION_1), _shouldHavePermission1);
      assertEq(nftPermissions.hasPermission(_positionId, _expected[i].operator, PERMISSION_2), _shouldHavePermission2);
      assertEq(nftPermissions.hasPermission(_positionId, _expected[i].operator, PERMISSION_3), _shouldHavePermission3);
    }
  }
}

library InternalUtils {
  function contains(INFTPermissions.Permission[] memory _permissions, INFTPermissions.Permission _permissionToCheck) internal pure returns (bool) {
    for (uint256 i; i < _permissions.length; i++) {
      if (INFTPermissions.Permission.unwrap(_permissions[i]) == INFTPermissions.Permission.unwrap(_permissionToCheck)) {
        return true;
      }
    }
    return false;
  }
}

contract ERC1271Contract is IERC1271 {
  function isValidSignature(bytes32 _hash, bytes memory _signature) external pure returns (bytes4 magicValue) {
    return _signature.length == 32 && _hash == bytes32(_signature) ? IERC1271.isValidSignature.selector : bytes4(0);
  }
}
