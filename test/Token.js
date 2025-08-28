const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");
const { expect } = require("chai");
const { ethers } = require("hardhat");

const { deployTokenFixture } = require("./helpers/TokenFixtures")

const tokens = (n) => {
    return ethers.parseUnits(n.toString(), 18);
}

describe("Token", () => { 
    describe("Deployment", () => {
        const NAME = "I Ptoken";
        const SYMBOL = "IPT";
        const DECIMALS = 18;
        const TOTAL_SUPPLY = tokens("1000000");

        it("has correct name", async () => {
            const { token } = await loadFixture(deployTokenFixture);
            expect(await token.name()).to.equal(NAME);
        });

        it("has correct symbol", async () => {
            const { token } = await loadFixture(deployTokenFixture);
            expect(await token.symbol()).to.equal(SYMBOL);
        });

        it("has correct decimals", async () => {
            const { token } = await loadFixture(deployTokenFixture);
            expect(await token.decimals()).to.equal(DECIMALS);
        });

        it("has correct total supply", async () => {
            const { token } = await loadFixture(deployTokenFixture);
            expect(await token.totalSupply()).to.equal(TOTAL_SUPPLY);
        });

        it("assigns total supply to the deployer", async () => {
            const { token, deployer } = await loadFixture(deployTokenFixture);
            expect(await token.balanceOf(deployer.address)).to.equal(TOTAL_SUPPLY);
        });
    }); // Close Deployment describe block

    describe("Sending Tokens", () => {  
        const AMOUNT = tokens(100);

        describe("Success", () => {
                    it("transfers token balances", async () => {
            const { token, deployer, receiver } = await loadFixture(deployTokenFixture);

            const transaction = await token.connect(deployer).transfer(receiver.address, tokens(100)); 
            await transaction.wait();

            expect(await token.balanceOf(deployer.address)).to.equal(tokens(999900));
            expect(await token.balanceOf(receiver.address)).to.equal(AMOUNT);
        });

        it("emits transfer event", async () => {
            const { token, deployer, receiver } = await loadFixture(deployTokenFixture);

            const transaction = await token.connect(deployer).transfer(receiver.address, AMOUNT); 
            const receipt = await transaction.wait()

            await expect(transaction).to.emit(token, "Transfer")
            .withArgs(deployer.address, receiver.address, AMOUNT)
        }) // Close "emits transfer event" it block

        });

        describe("Failure", () => {
                    it("rejects insufficient balances", async () => {
            const { token, deployer, receiver } = await loadFixture(deployTokenFixture);

            const INVALID_AMOUNT = tokens(100000000) // 100 million - greater than total supply
            const ERROR = "Token: Insufficient balance"

            await expect(token.connect(deployer).transfer(receiver.address, INVALID_AMOUNT)).to.be.revertedWith(ERROR)
       
        })

        it("rejects invalid recipient", async () => {
            const { token, deployer, receiver } = await loadFixture(deployTokenFixture);

            const INVALID_ADDRESS = "0x0000000000000000000000000000000000000000"
            const ERROR = "Token: Recipient address is 0"

            await expect(token.connect(deployer).transfer(INVALID_ADDRESS, AMOUNT))
                .to.be.revertedWith(ERROR)
        })

        });

        }); // Close Sending Tokens describe block
    
    }); // Close Token describe block
