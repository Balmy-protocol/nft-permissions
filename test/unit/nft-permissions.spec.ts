import { expect } from 'chai';
import { ethers } from 'hardhat';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { _TypedDataEncoder } from '@ethersproject/hash';
import { takeSnapshot, SnapshotRestorer } from '@nomicfoundation/hardhat-network-helpers'
import { BigNumber, BigNumberish, Contract, constants } from 'ethers';

describe('NFTPermissions', () => {
  const NFT_NAME = 'Mean Finance - DCA Position';
  const NFT_VERSION = '1';
  const OPERATOR = '0x0000000000000000000000000000000000000001'

  enum Permissions {
    PERMISSION_1,
    PERMISSION_2,
    PERMISSION_3,
  }

  let owner: SignerWithAddress, stranger: SignerWithAddress;
  let nftPermissions: Contract;
  let snapshotRestorer: SnapshotRestorer;
  let chainId: BigNumber;

  before('Setup accounts and contracts', async () => {
    [owner, stranger] = await ethers.getSigners();
    const factory = await ethers.getContractFactory('$NFTPermissions');
    nftPermissions = await factory.deploy(NFT_NAME, 'SYMBOL', NFT_VERSION);
    snapshotRestorer = await takeSnapshot();
    chainId = BigNumber.from((await ethers.provider.getNetwork()).chainId);
  });

  beforeEach(async () => {
    await snapshotRestorer.restore()
  });

  describe('permissionPermit', () => {
    const [POSITION_ID_1, POSITION_ID_2, POSITION_ID_3] = [1, 2, 3];

    beforeEach(async () => {
      await nftPermissions.$_mintWithPermissions(owner.address, [])
      await nftPermissions.$_mintWithPermissions(owner.address, [])
      await nftPermissions.$_mintWithPermissions(stranger.address, [])
    });

    multiPermissionPermitTest({
      when: 'setting only one permission',
      positions: [{ positionId: POSITION_ID_1, permissions: [Permissions.PERMISSION_1] }],
    });

    multiPermissionPermitTest({
      when: 'setting two permissions',
      positions: [
        { positionId: POSITION_ID_1, permissions: [Permissions.PERMISSION_1, Permissions.PERMISSION_2] },
        { positionId: POSITION_ID_2, permissions: [Permissions.PERMISSION_3, Permissions.PERMISSION_2] },
      ],
    });

    multiPermissionPermitTest({
      when: 'setting all permissions',
      positions: [
        { positionId: POSITION_ID_1, permissions: [Permissions.PERMISSION_1, Permissions.PERMISSION_2, Permissions.PERMISSION_3] },
        { positionId: POSITION_ID_2, permissions: [Permissions.PERMISSION_3, Permissions.PERMISSION_1, Permissions.PERMISSION_2] },
      ],
    });

    multiPermitFailsTest({
      when: 'no positions are passed',
      exec: () => signAndPermit({ signer: stranger, positions: [] }),
    });

    multiPermitFailsTest({
      when: 'some stranger tries to permit',
      exec: () => signAndPermit({ signer: stranger }),
      txFailsWith: 'InvalidSignature',
    });

    multiPermitFailsTest({
      when: 'permit has expired',
      exec: () => signAndPermit({ signer: owner, deadline: BigNumber.from(0) }),
      txFailsWith: 'ExpiredDeadline',
    });

    multiPermitFailsTest({
      when: 'chainId is different',
      exec: () => signAndPermit({ signer: owner, chainId: BigNumber.from(20) }),
      txFailsWith: 'InvalidSignature',
    });

    multiPermitFailsTest({
      when: 'signer signed something differently',
      exec: async () => {
        const data = withDefaults({ signer: owner, deadline: constants.MaxUint256 });
        const signature = await getSignature(data);
        return permissionPermit({ ...data, deadline: constants.MaxUint256.sub(1) }, signature);
      },
      txFailsWith: 'InvalidSignature',
    });

    multiPermitFailsTest({
      when: 'signature is reused',
      exec: async () => {
        const data = withDefaults({ signer: owner });
        const signature = await getSignature(data);
        await permissionPermit(data, signature);
        return permissionPermit(data, signature);
      },
      txFailsWith: 'InvalidSignature',
    });

    multiPermitFailsTest({
      when: 'signers tries to modify a position that is not theirs',
      exec: () =>
        signAndPermit({
          signer: owner,
          positions: [
            { positionId: POSITION_ID_1, permissionSets: [] }, // Belongs to signer
            { positionId: POSITION_ID_3, permissionSets: [] }, // Does not belong to signer
          ],
        }),
      txFailsWith: 'NotOwner',
    });

    function multiPermissionPermitTest({
      when: title,
      positions,
    }: {
      when: string;
      positions: { positionId: BigNumberish; permissions: Permissions[] }[];
    }) {
      describe(title, () => {
        beforeEach(async () => {
          const input = positions.map(({ positionId, permissions }) => ({ positionId, permissionSets: [{ operator: OPERATOR, permissions }] }));
          await signAndPermit({ signer: owner, positions: input });
        });

        it('operator gains permissions', async () => {
          for (const { positionId, permissions } of positions) {
            for (const permission of permissions) {
              expect(await nftPermissions.hasPermission(positionId, OPERATOR, permission)).to.be.true;
            }
          }
        });
      });
    }

    function multiPermitFailsTest({
      when: title,
      exec,
      txFailsWith: errorMessage,
    }: {
      when: string;
      exec: () => Promise<TransactionResponse>;
      txFailsWith?: string;
    }) {
      describe(title, () => {
        it('tx reverts', async () => {
          if (errorMessage) {
            await expect(exec()).to.be.revertedWithCustomError(nftPermissions, errorMessage)
          } else {
            await expect(exec()).to.be.reverted
          }
        });
      });
    }

    async function signAndPermit(options: Pick<OperationData, 'signer'> & Partial<OperationData>) {
      const data = withDefaults(options);
      const signature = await getSignature(data);
      return permissionPermit(data, signature);
    }

    async function permissionPermit(data: OperationData, signature: string) {
      return nftPermissions.permissionPermit(data.positions, data.deadline, signature);
    }

    function withDefaults(options: Pick<OperationData, 'signer'> & Partial<OperationData>): OperationData {
      return {
        nonce: BigNumber.from(0),
        deadline: constants.MaxUint256,
        positions: [{ positionId: POSITION_ID_1, permissionSets: [] }],
        chainId,
        ...options,
      };
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

    async function getSignature(options: OperationData) {
      const { domain, types, value } = buildPermitData(options);
      return await options.signer._signTypedData(domain, types, value);
    }

    function buildPermitData(value: OperationData) {
      return {
        primaryType: 'PermissionPermit',
        types: { PermissionPermit, PositionPermissions, PermissionSet },
        domain: { name: NFT_NAME, version: NFT_VERSION, chainId: value.chainId, verifyingContract: nftPermissions.address },
        value,
      };
    }

    type OperationData = {
      signer: SignerWithAddress;
      positions: {
        positionId: BigNumberish,
        permissionSets: { operator: string, permissions: Permissions[] }[]
      }[];
      nonce: BigNumber;
      deadline: BigNumber;
      chainId: BigNumber;
    };

    // Don't want to install extra dependencies just for this
    type TransactionResponse = any
  });
});
