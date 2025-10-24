const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

module.exports = buildModule("UserModule", (m) => {
    // Remember #0 is deployer and #1 is the fee account
    const USER = m.getAccount(2);

    // The exchange contract must already be deployed
    const EXCHANGE_ADDRESS = "0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9"; // Example address, replace with actual

    const FlashLoanUser = m.contract(
        "FlashLoanUser",
        [EXCHANGE_ADDRESS],
        { from: USER }
    );

    return { FlashLoanUser };
});
