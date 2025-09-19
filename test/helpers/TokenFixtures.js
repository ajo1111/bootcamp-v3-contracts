async function deployTokenFixture() {
    const Token = await ethers.getContractFactory("Token");
    const token = await Token.deploy("I Ptoken", "IPT", 1000000);

    const accounts = await ethers.getSigners();
    const deployer = accounts[0];
    const receiver = accounts[1];
    const exchange = accounts[2];

    return { token, deployer, receiver, exchange}
}

async function transferfromTokenFixture() {
    const { token, deployer, receiver, exchange } = await deployTokenFixture()

    const AMOUNT = ethers.parseUnits("100", 18);

    const approveTx = await token.connect(deployer).approve(exchange.address, AMOUNT);
    await approveTx.wait();

    const transaction = await token.connect(exchange).transferFrom(deployer.address, receiver.address, AMOUNT);
    await transaction.wait();

    return { token, deployer, receiver, exchange, transaction }
}

module.exports = {
    deployTokenFixture,
    transferfromTokenFixture
}
