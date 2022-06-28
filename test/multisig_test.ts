import { expect } from "chai";
import { ethers, waffle} from "hardhat";
import {Wallet} from '../typechain';
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";


let wallet: Wallet;
let admin: SignerWithAddress;
let owner1: SignerWithAddress;
let owner2: SignerWithAddress;
let owner3: SignerWithAddress;
let owner4: SignerWithAddress;
let owner5: SignerWithAddress;



describe("Testing the Multi-party Wallet", function () {
   this.beforeEach(async function () {
    const [addr1, addr2, addr3, addr4, addr5, addr6] = await ethers.getSigners();
    admin = addr1;
    owner1 = addr2
    owner2 = addr3
    owner3 = addr4
    owner4 = addr5
    owner5 = addr6

    const a = await ethers.getContractFactory("Wallet");
    wallet = await a.deploy(admin.address);
    await wallet.deployed();
  });

  it("Should allow only admin add addresses as a owner of the wallet contract", async function () {
   await wallet.connect(admin).addSingleOwner(owner1.address);
   expect (await wallet.checkOwnerExists(owner1.address)).to.equal(true)
    await wallet.connect(admin).addMultipleOwner([owner2.address, owner3.address, owner4.address, owner5.address]);
    expect (await wallet.checkOwnerExists(owner2.address)).to.equal(true)
    expect (await wallet.checkOwnerExists(owner3.address)).to.equal(true)
    expect (await wallet.checkOwnerExists(owner4.address)).to.equal(true)
    expect (await wallet.checkOwnerExists(owner5.address)).to.equal(true)
  });

  it("Should allow only admin remove  addresses as a owner of the wallet contract", async function () {
    await wallet.connect(admin).addSingleOwner(owner1.address);
   await wallet.connect(admin).removeSingleOwner(owner1.address);
   expect (await wallet.checkOwnerExists(owner1.address)).to.equal(false)

  });

  it("Should not allow  not-admin remove  or add addresses as a owner of the wallet contract", async function () {
  await expect (wallet.connect(owner2).addSingleOwner(owner1.address)).to.revertedWith('notAdmin');
  await expect (wallet.connect(owner2).removeSingleOwner(owner1.address)).to.revertedWith('notAdmin');

  });

  it("Should allow owner initiate a proposal for a transaction", async function () {
    await wallet.connect(admin).addSingleOwner(owner1.address);
    await wallet.connect(owner1).initiaiteTransactionProposal("30000000000000000000", 0)
    const proposal = await wallet.Proposals(1)
    await expect (proposal.initiator).to.equal(owner1.address)
  })

  it("Should allow othet owners approve a proposal for a transaction", async function () {
    await wallet.connect(admin).addMultipleOwner([owner2.address, owner3.address, owner4.address, owner1.address]);
    await wallet.connect(owner1).initiaiteTransactionProposal("30000000000000000000", 0);
    await wallet.connect(owner2).approveTransactionProposal(1);
    await wallet.connect(owner3).approveTransactionProposal(1);
    await wallet.connect(owner4).approveTransactionProposal(1);
    const proposal = await wallet.Proposals(1)
    await expect (Number(proposal.approver.toString())).to.equal(4)

  })

  it("Should allow owner execute proposal after quorum is met", async function () {
    await wallet.connect(admin).addMultipleOwner([owner2.address, owner3.address, owner4.address, owner1.address]);
    await wallet.connect(owner1).initiaiteTransactionProposal("30000000000000000000", 0);
    await wallet.connect(owner2).approveTransactionProposal(1);
    await wallet.connect(owner3).approveTransactionProposal(1);
    await wallet.connect(owner4).approveTransactionProposal(1);
    const options = {value: ethers.utils.parseEther("30.0")}
    await wallet.connect(owner1).executeProposal(1, options);
    const provider = waffle.provider;
    const contractBalance = await provider.getBalance(wallet.address)
   await expect (contractBalance.toString()).to.equal("30000000000000000000")
  })

  it("Should allow admin change quorum", async function () {
    await wallet.connect(admin).setQuorum(90);
    const quorum = await wallet.quorum();
    await expect (Number(quorum.toString())).to.equal(90)
  })

});
