const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");
const { expect } = require("chai");
const { ethers } = require("hardhat");

const { deployTokenFixture, transferfromTokenFixture } = require("./helpers/TokenFixtures");

const tokens = (n) => {
    return ethers.parseUnits(n.toString(), 18);
}

// Add AMOUNT constant at the top level
const AMOUNT = tokens(100);

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
        describe("Success", () => {
            it("transfers token balances", async () => {
                const { token, deployer, receiver } = await loadFixture(deployTokenFixture);

                const transaction = await token.connect(deployer).transfer(receiver.address, AMOUNT); 
                await transaction.wait();

                expect(await token.balanceOf(deployer.address)).to.equal(tokens(999900));
                expect(await token.balanceOf(receiver.address)).to.equal(AMOUNT);
            });

            it("emits transfer event", async () => {
                const { token, deployer, receiver } = await loadFixture(deployTokenFixture);

                const transaction = await token.connect(deployer).transfer(receiver.address, AMOUNT); 
                await transaction.wait();

                await expect(transaction).to.emit(token, "Transfer")
                    .withArgs(deployer.address, receiver.address, AMOUNT);
            });
        });

        describe("Failure", () => {
            it("rejects insufficient balances", async () => {
                const { token, deployer, receiver } = await loadFixture(deployTokenFixture);

                const invalidAmount = tokens(100000000);
                const error = "Token: Insufficient balance";

                await expect(token.connect(deployer).transfer(receiver.address, invalidAmount))
                    .to.be.revertedWith(error);
            });

            it("rejects invalid recipient", async () => {
                const { token, deployer } = await loadFixture(deployTokenFixture);

                const invalidAddress = "0x0000000000000000000000000000000000000000";
                await expect(token.connect(deployer).transfer(invalidAddress, AMOUNT))
                    .to.be.revertedWith("Token: Recipient address is 0");
            });
        });
    
    }); // Close Sending Tokens describe block

    describe("Approving Tokens", () => {  
        describe("Success", () => {
            it("allocates an allowance for delegated token spending", async () => {
                const { token, deployer, exchange } = await loadFixture(deployTokenFixture);

                const transaction = await token.connect(deployer).approve(exchange.address, AMOUNT) 
                await transaction.wait();

                expect(await token.allowance(deployer.address, exchange.address)).to.equal(AMOUNT);
            });
        
            it("emits an approval event", async () => {
                const { token, deployer, exchange } = await loadFixture(deployTokenFixture);

                const transaction = await token.connect(deployer).approve(exchange.address, AMOUNT); 
                const receipt = await transaction.wait()

                await expect(transaction).to.emit(token, "Approval")
                    .withArgs(deployer.address, exchange.address, AMOUNT)
            });
        });

        describe("Failure", () => {
            it("rejects invalid spenders", async () => {
                const { token, deployer } = await loadFixture(deployTokenFixture);

                const INVALID_ADDRESS = "0x0000000000000000000000000000000000000000" // Remove extra space
                const ERROR = "Token: Recipient address is 0" // Fixed spelling of "Recipient"

                await expect(token.connect(deployer).approve(INVALID_ADDRESS, AMOUNT))
                    .to.be.revertedWith(ERROR)
            });
        });

    }); // Close Approving Tokens describe block
});

describe("Delegated Token Transfers", () => {  
    describe("Success", () => {
        it("transfers token balances", async () => {
            const { token, deployer, receiver, amount } = await loadFixture(transferfromTokenFixture);

            expect(await token.balanceOf(deployer.address)).to.equal(tokens(999900));
            expect(await token.balanceOf(receiver.address)).to.equal(amount);
        });

        it("resets the allowance", async () => {
            const { token, deployer, exchange } = await loadFixture(transferfromTokenFixture);
            expect(await token.allowance(deployer.address, exchange.address)).to.equal(0);
        });

        it("emits transfer event", async () => {
            const { token, deployer, receiver, amount, transaction } = await loadFixture(transferfromTokenFixture);
            
            await expect(transaction)
                .to.emit(token, "Transfer")
                .withArgs(deployer.address, receiver.address, amount);
        });
    });

    describe("Failure", () => {
        it("rejects insufficient allowance", async () => {
            const { token, deployer, receiver, exchange } = await loadFixture(deployTokenFixture); // Note: using deployTokenFixture

            const amount = tokens(100);
            const ERROR = "Token: Insufficient Allowance";

            // Try to transfer without approval
            await expect(token.connect(exchange).transferFrom(deployer.address, receiver.address, amount))
                .to.be.revertedWith(ERROR);
        });
        
        it("rejects insufficient amounts", async () => {
            const { token, deployer, receiver, exchange } = await loadFixture(deployTokenFixture);
            
            const amount = tokens(100);
            const invalidAmount = tokens(100000000); // Amount greater than total supply
            const ERROR = "Token: Insufficient Funds"; // Changed from "Token: Insufficient balance"

            // First approve tokens
            await token.connect(deployer).approve(exchange.address, amount);

            // Try to transfer more than approved amount
            await expect(token.connect(exchange).transferFrom(
                deployer.address, 
                receiver.address, 
                invalidAmount
            )).to.be.revertedWith(ERROR);
        });
    });
});





