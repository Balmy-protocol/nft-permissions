import { HardhatUserConfig } from 'hardhat/types';
import '@nomiclabs/hardhat-ethers';
import '@nomicfoundation/hardhat-foundry';
import '@nomicfoundation/hardhat-toolbox';
import '@nomicfoundation/hardhat-chai-matchers';
import '@nomicfoundation/hardhat-network-helpers';
import 'hardhat-exposed';

const config: HardhatUserConfig = {
  defaultNetwork: 'hardhat',
  solidity: {
    version: '0.8.28'
  },
};

export default config;
