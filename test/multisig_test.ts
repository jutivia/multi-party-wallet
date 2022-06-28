import { expect } from "chai";
import { ethers } from "hardhat";
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
    const a = await ethers.getContractFactory("Wallet");
    wallet = await a.deploy();
    await wallet.deployed();
    const [addr1, addr2, addr3, addr4, addr5, addr6] = await ethers.getSigners();
    admin = addr1;
    owner1 = addr2
    owner2 = addr3
    owner3 = addr4
    owner4 = addr5
    owner5 = addr6
  });

  // it("Should return the new greeting once it's changed", async function () {
   
  // });
});
