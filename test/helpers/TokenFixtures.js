const { ethers } = require("hardhat");

const tokens = (n) => {
    return ethers.parseUnits(n.toString(), 18);
}

async function deployTokenFixture() {
    const NAME = "I Ptoken";
    const SYMBOL = "IPT";
    const TOTAL_SUPPLY = "1000000";

    const Token = await ethers.getContractFactory("Token");
    const [deployer, receiver, exchange] = await ethers.getSigners();

    const token = await Token.deploy(NAME, SYMBOL, TOTAL_SUPPLY);

    return { 
        token, 
        deployer, 
        receiver, 
        exchange 
    };
}

async function transferfromTokenFixture() {
    const NAME = "I Ptoken";
    const SYMBOL = "IPT";
    const TOTAL_SUPPLY = "1000000";

    const Token = await ethers.getContractFactory("Token");
    const [deployer, receiver, exchange] = await ethers.getSigners();

    const token = await Token.deploy(NAME, SYMBOL, TOTAL_SUPPLY);
    const amount = tokens(100);

    // Approve tokens
    const transaction = await token.connect(deployer).approve(exchange.address, amount);
    await transaction.wait();

    // Execute transfer
    const transferTx = await token.connect(exchange).transferFrom(
        deployer.address,
        receiver.address,
        amount
    );
    await transferTx.wait();

    return {
        token,
        deployer,
        receiver,
        exchange,
        amount,
        transaction: transferTx
    };
}

module.exports = { 
    deployTokenFixture,
    transferfromTokenFixture 
};
