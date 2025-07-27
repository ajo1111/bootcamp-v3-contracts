async function deployTokenFixture() {
    const Token = await ethers.getContractFactory("Token");
    const token = await Token.deploy("I Ptoken", "IPT", 1000000);

    const accounts = await ethers.getSigners();
    const deployer = accounts[0];

    return { token, deployer }
}

module.exports = {
    deployTokenFixture
}
