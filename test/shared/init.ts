import { ethers, upgrades } from 'hardhat';
import { Contract, Signer } from 'ethers';
const sha3 = require('web3-utils').sha3;
const namehash = require('eth-ens-namehash');

const overrides = {
  gasLimit: 9999999
}

const confs = {
  ZERO_ADDRESS: "0x0000000000000000000000000000000000000000",
  ZERO_HASH: "0x0000000000000000000000000000000000000000000000000000000000000000",
  registFees: [
    {charNum: 3, feeAmount: ethers.utils.parseUnits('150', 18)},
    {charNum: 4, feeAmount: ethers.utils.parseUnits('20', 18)},
    {charNum: 5, feeAmount: ethers.utils.parseUnits('3', 18)}
  ],
  rebates: [
    {number: 10, rates: 5},
    {number: 30, rates: 10},
    {number: 9999, rates: 15}
  ],
  retains: [sha3('god')]
}

interface V2Fixture {
  mockToken: Contract,
  fnsRegistry: Contract,
  nameRegistrar: Contract,
  nameResolver: Contract,
  reverseRegistrar: Contract,
  owner: Signer,
  manager: Signer,
  aUser: Signer,
  bUser: Signer,
  cUser: Signer,
  dUser: Signer,
  eUser: Signer,
  fUser: Signer,
  gUser: Signer
}

function getAddDaysTime(addDay:number) {
  return Math.floor(new Date().getTime() / 1000) + 60 * 60 * 24 * addDay;
}

export async function v2Fixture(): Promise<V2Fixture> {
  const [ owner, manager, aUser, bUser, cUser, dUser, eUser, fUser, gUser ] = await ethers.getSigners();
  // deploy tokens
  const MockToken = await ethers.getContractFactory('MockToken');
  const mockToken = await MockToken.deploy('TEST', ethers.utils.parseUnits('10000', 18));
  await mockToken.mint(bUser.getAddress(), ethers.utils.parseUnits('10000', 18));
  await mockToken.mint(cUser.getAddress(), ethers.utils.parseUnits('10000', 18));
  // deploy FNSRegistry
  const FNSRegistry = await ethers.getContractFactory('FNSRegistry');
  const fnsRegistry = await upgrades.deployProxy(FNSRegistry, { initializer: 'initialize' });
  await fnsRegistry.deployed();
  // deploy NameResolver
  const NameResolver = await ethers.getContractFactory('NameResolver');
  const nameResolver = await upgrades.deployProxy(NameResolver, { initializer: 'initialize' });
  await nameResolver.deployed();
  // deploy ReverseRegistrar
  const ReverseRegistrar = await ethers.getContractFactory('ReverseRegistrar');
  const reverseRegistrar = await upgrades.deployProxy(
    ReverseRegistrar,
    [
      fnsRegistry.address,
      nameResolver.address
    ],
    { initializer: 'initialize' }
  )
  await reverseRegistrar.deployed();
  // deploy NameRegistrar
  const NameRegistrar = await ethers.getContractFactory('NameRegistrar');
  const nameRegistrar = await upgrades.deployProxy(
    NameRegistrar,
    [
      fnsRegistry.address,
      reverseRegistrar.address,
      namehash.hash('fra'),
      await owner.getAddress(),
      mockToken.address
    ],
    { initializer: 'initialize' }
  );
  await nameRegistrar.deployed();
  await fnsRegistry.addManager(nameRegistrar.address);
  await nameResolver.addManager(nameRegistrar.address);
  // set
  await fnsRegistry.setSubnodeOwner(
    confs.ZERO_HASH,
    'fra',
    sha3('fra'),
    nameRegistrar.address
  );
  await fnsRegistry.setSubnodeOwner(
    confs.ZERO_HASH,
    'reverse',
    sha3('reverse'), 
    owner.address
  );
  await fnsRegistry.setSubnodeOwner(
    namehash.hash('reverse'),
    'addr',
    sha3('addr'),
    reverseRegistrar.address
  );
  await nameRegistrar.addManager(await manager.getAddress());
  await nameRegistrar.setRegistFees(confs.registFees);
  await nameRegistrar.setRebates(confs.rebates);
  await nameRegistrar.addRetains(confs.retains);
  await nameRegistrar.setFirstClaimTime(getAddDaysTime(3), getAddDaysTime(5));
  await nameRegistrar.setSecondClaimTime(getAddDaysTime(5), getAddDaysTime(7));
  await nameRegistrar.setPublicTime(getAddDaysTime(10));
  await nameRegistrar.setSpecial(getAddDaysTime(11), getAddDaysTime(12), 1, true);

  return {
    mockToken,
    fnsRegistry,
    nameRegistrar,
    nameResolver,
    reverseRegistrar,
    owner,
    manager,
    aUser,
    bUser,
    cUser,
    dUser,
    eUser,
    fUser,
    gUser
  }
}