import chai, { expect } from 'chai';
import { ethers } from 'hardhat';
import { Contract, Signer, BigNumber, utils } from 'ethers';
import { solidity } from 'ethereum-waffle';
const { sha3 } = require('web3-utils');
const namehash = require('eth-ens-namehash');
import { v2Fixture } from './shared/init';

chai.use(solidity)

const confs = {
    duration: 1,
    ZERO_ADDRESS: "0x0000000000000000000000000000000000000000",
    ZERO_HASH: "0x0000000000000000000000000000000000000000000000000000000000000000"
}

describe("fns tests", ()=> {

    let mockToken: Contract;
    let fnsRegistry: Contract;
    let nameRegistrar: Contract;
    let nameResolver: Contract;
    let reverseRegistrar: Contract;
    let aUser: Signer;
    let bUser: Signer;
    let cUser: Signer;
    let dUser: Signer;
    let eUser: Signer;
    let fUser: Signer;
    let gUser: Signer;

    before(async () => {
        const fixture = await v2Fixture();
        mockToken = fixture.mockToken;
        fnsRegistry = fixture.fnsRegistry;
        nameRegistrar = fixture.nameRegistrar;
        nameResolver = fixture.nameResolver;
        reverseRegistrar = fixture.reverseRegistrar;
        aUser = fixture.aUser;
        bUser = fixture.bUser;
        cUser = fixture.cUser;
        dUser = fixture.dUser;
        eUser = fixture.eUser;
        fUser = fixture.fUser;
        gUser = fixture.gUser;
    })

    function getAddDaysTime(addDay:number) {
        return Math.floor(new Date().getTime() / 1000) + 60 * 60 * 24 * addDay;
    }

    async function getSignature(account:string, labelStr:string) {
        const messageHash = ethers.utils.solidityKeccak256(
            ["uint", "string", "address"], [getAddDaysTime(1), labelStr, account]
        )
        const messageBytes = ethers.utils.arrayify(messageHash)
        return await gUser.signMessage(messageBytes)
    }

    it("check time & signature", async()=> {
        await expect(
            nameRegistrar.firstClaim()
        ).to.be.revertedWith('not in time')
        await expect(
            nameRegistrar.secondClaim()
        ).to.be.revertedWith('not in time')
        await expect(
            nameRegistrar.preemptRegister(
                'andy',
                confs.duration,
                confs.ZERO_HASH,
                await getSignature(await bUser.getAddress(), 'andy'),
                getAddDaysTime(1)
            )
        ).to.be.revertedWith('invalid signature')
        // add manager
        await nameRegistrar.addManager(await gUser.getAddress())
        await expect(
            nameRegistrar.preemptRegister(
                'andy',
                confs.duration,
                confs.ZERO_HASH,
                await getSignature(await aUser.getAddress(), 'andy'),
                getAddDaysTime(1)
            )
        ).to.be.revertedWith('not in time')
        await expect(
            nameRegistrar.register(
                'andy',
                confs.duration,
                confs.ZERO_HASH,
                await getSignature(await aUser.getAddress(), 'andy'),
                getAddDaysTime(1)
            )
        ).to.be.revertedWith('not in time')
    })

    it("not the manager", async()=> {
        await expect(
            nameRegistrar.beforehandRegister(
                await aUser.getAddress(),
                'advance',
                1
            )
        ).to.be.revertedWith('NameRegistrar: Caller is not the manager')
    })

    it("first register", async()=> {
        await nameRegistrar.connect(gUser).beforehandRegister(
            await aUser.getAddress(),
            'advance',
            1
        )
    })

    it("second register", async()=> {
        await nameRegistrar.connect(gUser).beforehandRegister(
            await aUser.getAddress(),
            'advance2',
            2
        )
    })

    it("first claim", async()=> {
        await nameRegistrar.setFirstClaimTime(getAddDaysTime(0), getAddDaysTime(3));
        await nameRegistrar.connect(aUser).firstClaim();
        expect(await nameRegistrar.ownerOf(
            BigNumber.from(sha3('advance'))
        )).to.eq(await aUser.getAddress());
    })

    it("second claim", async()=> {
        await nameRegistrar.setSecondClaimTime(getAddDaysTime(0), getAddDaysTime(3));
        await nameRegistrar.connect(aUser).secondClaim();
        expect(await nameRegistrar.ownerOf(
            BigNumber.from(sha3('advance2'))
        )).to.eq(await aUser.getAddress());
    })

    it("registrar retains not open", async()=> {
        await expect(
            nameRegistrar.connect(bUser).register(
                'god',
                confs.duration,
                confs.ZERO_HASH,
                await getSignature(await bUser.getAddress(), 'god'),
                getAddDaysTime(1)
            )
        ).to.be.revertedWith('not open')
    })

    it("preempt register", async()=> {
        await nameRegistrar.setPreemptTime(getAddDaysTime(0), getAddDaysTime(3));
        await expect(
            nameRegistrar.connect(cUser).preemptRegister(
                'preempt',
                confs.duration,
                confs.ZERO_HASH,
                await getSignature(await cUser.getAddress(), 'preempt'),
                getAddDaysTime(1)
            )
        ).to.be.revertedWith('no permission')
        await nameRegistrar.addPreemptWhiteLists([await cUser.getAddress()])
        await mockToken.connect(cUser).approve(nameRegistrar.address, ethers.utils.parseUnits('1000', 18));
        await nameRegistrar.connect(cUser).preemptRegister(
            'preempt',
            confs.duration,
            confs.ZERO_HASH,
            await getSignature(await cUser.getAddress(), 'preempt'),
            getAddDaysTime(1)
        )
        expect(await nameRegistrar.ownerOf(
            BigNumber.from(sha3('preempt'))
        )).to.eq(await cUser.getAddress());
    })

    it("registrar no recommender", async()=> {
        await nameRegistrar.setPublicTime(getAddDaysTime(0));
        await mockToken.connect(bUser).approve(nameRegistrar.address, ethers.utils.parseUnits('1000', 18));
        await nameRegistrar.connect(bUser).register(
            'first',
            confs.duration,
            confs.ZERO_HASH,
            await getSignature(await bUser.getAddress(), 'first'),
            getAddDaysTime(1)
        );
        let records = await fnsRegistry.records(namehash.hash('first.fra'));
        let expiries = await nameRegistrar.expiries(BigNumber.from(sha3('first')));
        let balance = await mockToken.balanceOf(nameRegistrar.address);
        expect(ethers.utils.formatUnits(balance, 18)).to.eq('6.0');
        expect(
            JSON.parse(
                await fnsRegistry.currentText(namehash.hash('first.fra'))
            ).ETH
        ).to.eq(utils.hexValue(await bUser.getAddress()));
        expect(await fnsRegistry.currentOwner(namehash.hash('first.fra'))).to.eq(await bUser.getAddress());
        expect(expiries.toString()).to.eq((records[3] - 60 * 60 * 24 * 30).toString())
    })

    it("repeat registrar", async()=> {
        await expect(
            nameRegistrar.connect(bUser).register(
                'first',
                confs.duration,
                confs.ZERO_HASH,
                await getSignature(await bUser.getAddress(), 'first'),
                getAddDaysTime(1)
            )
        ).to.be.revertedWith('using')
    })

    it("registrar by recommender", async()=> {
        await mockToken.connect(cUser).approve(nameRegistrar.address, ethers.utils.parseUnits('1000', 18));
        await nameRegistrar.connect(cUser).register(
            'second',
            confs.duration,
            namehash.hash('first.fra'),
            await getSignature(await cUser.getAddress(), 'second'),
            getAddDaysTime(1)
        );
        let balance = await mockToken.balanceOf(nameRegistrar.address);
        expect(ethers.utils.formatUnits(balance, 18)).to.eq('8.85');
        expect(await fnsRegistry.currentOwner(namehash.hash('second.fra'))).to.eq(await cUser.getAddress());
    })

    it("regist child", async()=> {
        await fnsRegistry.connect(cUser).setSubnodeOwner(
            namehash.hash('second.fra'),
            'sub',
            sha3('sub'),
            await dUser.getAddress()
        )
        expect(await fnsRegistry.currentOwner(namehash.hash('sub.second.fra'))).to.eq(await dUser.getAddress());
        let subRelation = await fnsRegistry.getSubRelations(namehash.hash('second.fra'));
        expect(subRelation[0]).to.eq(namehash.hash('sub.second.fra'));
        let subDetails = await fnsRegistry.subDetails(namehash.hash('sub.second.fra'));
        expect(subDetails[1]).to.eq('sub');

        await fnsRegistry.connect(bUser).setSubnodeOwner(
            namehash.hash('first.fra'),
            'sub',
            sha3('sub'),
            await dUser.getAddress()
        )
        let parentRelations = await fnsRegistry.parentRelations(namehash.hash('sub.first.fra'));
        let subRelations = await fnsRegistry.getSubRelations(namehash.hash('first.fra'));
        subDetails = await fnsRegistry.subDetails(namehash.hash('sub.first.fra'));
        expect(parentRelations).to.eq(namehash.hash('first.fra'));
        expect(subRelations[0]).to.eq(namehash.hash('sub.first.fra'));
        expect(subDetails[1]).to.eq('sub');
    })

    it("del sub", async()=> {
        await fnsRegistry.connect(bUser).setSubnodeOwner(
            namehash.hash('first.fra'),
            'del',
            sha3('del'),
            await dUser.getAddress()
        )
        let subRelations = await fnsRegistry.getSubRelations(namehash.hash('first.fra'));
        expect(subRelations[1]).to.eq(namehash.hash('del.first.fra'));
        await fnsRegistry.connect(dUser).delSubnodeOwner(
            namehash.hash('del.first.fra')
        )
        subRelations = await fnsRegistry.getSubRelations(namehash.hash('first.fra'));
        expect(subRelations.length).to.eq(1);
    })

    it("third floor sub", async()=> {
        await expect(
            fnsRegistry.connect(dUser).setSubnodeOwner(
                namehash.hash('sub.second.fra'),
                'third',
                sha3('third'),
                await dUser.getAddress()
            )
        ).to.be.revertedWith('exceeds max level')
    })

    it("Subdomain name restriction", async()=> {
        for(let i = 0;i < 9; i++){
            await fnsRegistry.connect(cUser).setSubnodeOwner(
                namehash.hash('second.fra'),
                'sub' + i,
                sha3('sub' + i),
                await dUser.getAddress()
            )
        }
        await expect(
            fnsRegistry.connect(cUser).setSubnodeOwner(
                namehash.hash('second.fra'),
                'sub9',
                sha3('sub9'),
                await dUser.getAddress()
            )
        ).to.be.revertedWith('exceeds max sub count')
    })

    it("set operator", async()=> {
        await fnsRegistry.connect(dUser).setApprovalForAll(
            namehash.hash('sub.second.fra'),
            await fUser.getAddress()
        );
        expect(await fnsRegistry.isApprovedForAll(
            namehash.hash('sub.second.fra'),
            await fUser.getAddress()
        )).to.eq(true);
    })

    it("set text", async()=> {
        let jsonObj = {'address':{'ETH': 'ETH'}, 'concent':'concent'};
        await fnsRegistry.connect(fUser).setText(
            namehash.hash('sub.second.fra'),
            JSON.stringify(jsonObj)
        );
        let text = await fnsRegistry.currentText(namehash.hash('sub.second.fra'));
        expect(JSON.parse(text).address.ETH).to.eq('ETH');
    })

    it("regist details", async()=> {
        let registDetail = await nameRegistrar.registDetails(
            BigNumber.from(sha3('first'))
        );
        expect(registDetail[0]).to.eq('first');
    })

    it("recommend statistics", async()=> {
        let statistics = await nameRegistrar.recommendStatistics(await bUser.getAddress());
        expect(statistics[0].toString()).to.eq('1');
        expect(ethers.utils.formatUnits(statistics[1], 18)).to.eq('0.1425');
        expect(ethers.utils.formatUnits(statistics[2], 18)).to.eq('0.0');
    })

    it("recommend detail", async()=> {
        let details = await nameRegistrar.getRecommendDetails(await bUser.getAddress());
        expect(details[0][0]).to.eq('second');
        expect(details[0][1].toString()).to.eq(BigNumber.from(sha3('second')).toString());
    })

    it("claim rewards", async()=> {
        let balance = await mockToken.balanceOf(nameRegistrar.address);
        await nameRegistrar.connect(bUser).claimRewards();
        let statistics = await nameRegistrar.recommendStatistics(await bUser.getAddress());
        let newBalance = await mockToken.balanceOf(nameRegistrar.address);
        expect(ethers.utils.formatUnits(statistics[2], 18)).to.eq('0.1425');
        expect(ethers.utils.formatUnits(
            BigNumber.from(balance).sub(BigNumber.from(newBalance)), 
            18)).to.eq('0.1425');
    })

    it("withraw fee", async()=> {
        let balance = await mockToken.balanceOf(nameRegistrar.address);
        await nameRegistrar.connect(aUser).withrawFee(
            await bUser.getAddress(),
            ethers.utils.parseUnits('2', 18)
        );
        let newBalance = await mockToken.balanceOf(nameRegistrar.address);
        expect(ethers.utils.formatUnits(
            BigNumber.from(balance).sub(BigNumber.from(newBalance)), 
            18)).to.eq('2.0');
    })

    it("renew", async()=> {
        await nameRegistrar.connect(bUser).renew('first', 1);
        let expiries = await nameRegistrar.expiries(BigNumber.from(sha3('first')));
        let records = await fnsRegistry.records(namehash.hash('first.fra'));
        let subRecords = await fnsRegistry.records(namehash.hash('sub.first.fra'));
        let registDetails = await nameRegistrar.registDetails(
            BigNumber.from(sha3('first'))
        );
        expect(
            expiries.toString()
        ).to.eq(registDetails[4].toString())
        .to.eq((records[3] - 60 * 60 * 24 * 30).toString())
        .to.eq((subRecords[3] - 60 * 60 * 24 * 30).toString())
    })

    it("NFT owner", async()=> {
        expect(await nameRegistrar.ownerOf(
            BigNumber.from(sha3('first'))
        )).to.eq(await bUser.getAddress());
        expect(await nameRegistrar.ownerOf(
            BigNumber.from(sha3('second'))
        )).to.eq(await cUser.getAddress());
    })

    it("transfer NFT", async()=> {
        await nameRegistrar.connect(bUser)["safeTransferFrom(address,address,uint256)"](
                await bUser.getAddress(),
                await eUser.getAddress(),
                BigNumber.from(sha3('first'))
        );
        expect(await nameRegistrar.ownerOf(
            BigNumber.from(sha3('first'))
        )).to.eq(await eUser.getAddress());
    })

    it("NFT reclaim", async()=> {
        await nameRegistrar.connect(eUser).reclaim(
            'first'
        );
        expect(await fnsRegistry.currentOwner(namehash.hash('first.fra')))
        .to.eq(await eUser.getAddress());
        let parentRelations = await fnsRegistry.parentRelations(namehash.hash('sub.first.fra'));
        let subRelations = await fnsRegistry.getSubRelations(namehash.hash('first.fra'));
        let subDetails = await fnsRegistry.subDetails(namehash.hash('sub.first.fra'));
        expect(parentRelations).to.eq(confs.ZERO_HASH);
        expect(subRelations.length).to.eq(0);
        expect(subDetails[1]).to.eq('');
    })

    it("merge transfer", async()=> {
        await nameRegistrar.connect(cUser).mergeTransfer(
            'second',
            await eUser.getAddress()
        );
        expect(await nameRegistrar.ownerOf(
            BigNumber.from(sha3('second'))
        )).to.eq(await eUser.getAddress());
        expect(await fnsRegistry.currentOwner(namehash.hash('second.fra')))
        .to.eq(await eUser.getAddress());
    })

    it("reverse", async()=> {
        await reverseRegistrar.connect(eUser).setName('test');
        expect(await fnsRegistry.currentOwner(
            namehash.hash((await eUser.getAddress()).slice(2).toLowerCase() + '.addr.reverse')))
        .to.eq(reverseRegistrar.address);
        expect(await fnsRegistry.currentResolver(
            namehash.hash((await eUser.getAddress()).slice(2).toLowerCase() + '.addr.reverse')))
        .to.eq(nameResolver.address);
        expect(await nameResolver.name(
            namehash.hash((await eUser.getAddress()).slice(2).toLowerCase() + '.addr.reverse')))
        .to.eq('test');
    })
})