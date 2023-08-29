import { expect } from 'chai';
import { ethers } from 'hardhat';
import { Contract, BigNumberish } from 'ethers';
import { _TypedDataEncoder, } from '@ethersproject/hash';

describe('Permission Hash', () => {

  enum Permissions {
    PERMISSION_1,
    PERMISSION_2,
    PERMISSION_3,
  }
  const ADDRESS1 = '0x0000000000000000000000000000000000000001'
  const ADDRESS2 = '0x0000000000000000000000000000000000000002'
  let permissionHash: Contract;
  let encoder: _TypedDataEncoder

  before(async () => {
    const factory = await ethers.getContractFactory('$PermissionHash');
    permissionHash = await factory.deploy()
    encoder = _TypedDataEncoder.from({ PermissionSet, PermissionPermit, PositionPermissions })
  });

  testHashTest({
    title: 'permissions list',
    functionName: '$hash(uint8[])',
    value: [Permissions.PERMISSION_1, Permissions.PERMISSION_2],
    valueType: 'uint8[]',
  })

  testHashTest({
    title: 'permissions set',
    functionName: '$hash((address,uint8[]))',
    value: {
      operator: ADDRESS1,
      permissions: [Permissions.PERMISSION_1, Permissions.PERMISSION_2]
    },
    valueType: 'PermissionSet',
    isStruct: true,
  })

  testHashTest({
    title: 'permissions set list',
    functionName: '$hash((address,uint8[])[])',
    value: [
      { operator: ADDRESS1, permissions: [Permissions.PERMISSION_1, Permissions.PERMISSION_2] },
      { operator: ADDRESS2, permissions: [Permissions.PERMISSION_3, Permissions.PERMISSION_1] },
    ],
    valueType: 'PermissionSet[]',
  })

  testHashTest({
    title: 'position permissions',
    functionName: '$hash((uint256,(address,uint8[])[]))',
    value: {
      positionId: 1,
      permissionSets: [
        { operator: ADDRESS1, permissions: [Permissions.PERMISSION_1, Permissions.PERMISSION_2] },
        { operator: ADDRESS2, permissions: [Permissions.PERMISSION_3, Permissions.PERMISSION_1] },
      ]
    },
    valueType: 'PositionPermissions',
    isStruct: true
  })

  testHashTest({
    title: 'position permissions list',
    functionName: '$hash((uint256,(address,uint8[])[])[])',
    value: [
      {
        positionId: 1,
        permissionSets: [
          { operator: ADDRESS1, permissions: [Permissions.PERMISSION_1, Permissions.PERMISSION_2] },
          { operator: ADDRESS2, permissions: [Permissions.PERMISSION_3, Permissions.PERMISSION_1] },
        ]
      },
      {
        positionId: 2,
        permissionSets: [
          { operator: ADDRESS2, permissions: [Permissions.PERMISSION_2, Permissions.PERMISSION_3] },
          { operator: ADDRESS2, permissions: [Permissions.PERMISSION_1, Permissions.PERMISSION_3] },
        ]
      }
    ],
    valueType: 'PositionPermissions[]',
  })

  testHashTest({
    title: 'permission permit',
    functionName: '$hash((uint256,(address,uint8[])[])[],uint256,uint256)',
    value: {
      positions: [
        {
          positionId: 1,
          permissionSets: [
            { operator: ADDRESS1, permissions: [Permissions.PERMISSION_1, Permissions.PERMISSION_2] },
            { operator: ADDRESS2, permissions: [Permissions.PERMISSION_3, Permissions.PERMISSION_1] },
          ]
        },
        {
          positionId: 2,
          permissionSets: [
            { operator: ADDRESS2, permissions: [Permissions.PERMISSION_2, Permissions.PERMISSION_3] },
            { operator: ADDRESS2, permissions: [Permissions.PERMISSION_1, Permissions.PERMISSION_3] },
          ]
        }
      ],
      nonce: 10,
      deadline: 20
    },
    valueType: 'PermissionPermit',
    isStruct: true,
    spreadParams: (params => [params.positions, params.nonce, params.deadline])
  })

  function testHashTest({ title, functionName, value, valueType, isStruct, spreadParams }: {
    title: string,
    functionName: string,
    value: any,
    valueType: string,
    isStruct?: boolean,
    spreadParams?: (value: any) => any[],
  }) {
    it(title, async () => {
      const calculatedHash = await (spreadParams ? permissionHash[functionName](...spreadParams(value)) : permissionHash[functionName](value))
      const expectedHash = isStruct
        ? encoder.hashStruct(valueType, value)
        : encoder.encodeData(valueType, value)
      expect(calculatedHash).to.eql(expectedHash)
    })
  }

  const PermissionSet = [
    { name: 'operator', type: 'address' },
    { name: 'permissions', type: 'uint8[]' },
  ];

  const PositionPermissions = [
    { name: 'positionId', type: 'uint256' },
    { name: 'permissionSets', type: 'PermissionSet[]' },
  ]

  const PermissionPermit = [
    { name: 'positions', type: 'PositionPermissions[]' },
    { name: 'nonce', type: 'uint256' },
    { name: 'deadline', type: 'uint256' },
  ];

  type PermissionSet = {
    operator: string,
    permissions: Permissions[]
  }

  type PositionPermissions = {
    positionId: BigNumberish,
    permissionSets: PermissionSet[]
  }

});
