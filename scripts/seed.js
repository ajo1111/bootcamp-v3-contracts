const hre = require("hardhat");

const tokens = (n) => {
    return ethers.parseUnits(n.toString(), 18);
}

function wait(seconds) {
    const milliseconds = seconds * 1000
    return new Promise(resolve => setTimeout(resolve, milliseconds))
}

async function main() {
    // Fetch accounts from wallet - these are unlocked
    const accounts = await ethers.getSigners();

    // This is the main account who deploys the contracts
    const deployer = accounts[0];

    // This is who collects fees from the exchange
    const collector = accounts[1];

    // These will represent a regular users
    const user1 = accounts[2];
    const user2 = accounts[3];

    // Deploy Token contracts
    const Token = await ethers.getContractFactory("Token");

    const ipt = await Token.deploy("Impact Token", "IPT", "1000000");
    await ipt.waitForDeployment();
    console.log(`IPT Token deployed to: ${await ipt.getAddress()}`);

    const musdc = await Token.deploy("Mock USDC", "mUSDC", "1000000");
    await musdc.waitForDeployment();
    console.log(`mUSDC Token deployed to: ${await musdc.getAddress()}`);

    const mlink = await Token.deploy("Mock LINK", "mLINK", "1000000");
    await mlink.waitForDeployment();
    console.log(`mLINK Token deployed to: ${await mlink.getAddress()}`);

    // Deploy Exchange
    const Exchange = await ethers.getContractFactory("Exchange");
    const exchange = await Exchange.deploy(collector.address, 10);
    await exchange.waitForDeployment();
    console.log(`Exchange deployed to: ${await exchange.getAddress()}`);

    // Deploy FlashLoanUser
    const FlashLoanUser = await ethers.getContractFactory("FlashLoanUser");
    const flashLoanUser = await FlashLoanUser.deploy(await exchange.getAddress());
    await flashLoanUser.waitForDeployment();
    console.log(`FlashLoanUser deployed to: ${await flashLoanUser.getAddress()}\n`);

    const IPT_ADDRESS = await ipt.getAddress();
    const mUSDC_ADDRESS = await musdc.getAddress();
    const mLINK_ADDRESS = await mlink.getAddress();

    // -----
    // Distribute tokens
    // -----

    let transaction, result;

    // Deployer transfers 10,000 IPT to user1...
    transaction = await ipt.connect(deployer).transfer(user1.address, tokens(10000));
    await transaction.wait();
    console.log(`Transferred 10000 IPT from ${deployer.address} to ${user1.address}\n`);

    // Deployer transfers 10,000 mUSDC to user2...
    transaction = await musdc.connect(deployer).transfer(user2.address, tokens(10000));
    await transaction.wait();
    console.log(`Transferred 10000 mUSDC from ${deployer.address} to ${user2.address}\n`);

    // Give user1 some mUSDC too
    transaction = await musdc.connect(deployer).transfer(user1.address, tokens(10000));
    await transaction.wait();
    console.log(`Transferred 10000 mUSDC from ${deployer.address} to ${user1.address}\n`);

    // Give user2 some IPT too
    transaction = await ipt.connect(deployer).transfer(user2.address, tokens(10000));
    await transaction.wait();
    console.log(`Transferred 10000 IPT from ${deployer.address} to ${user2.address}\n`);

    // -----
    // Users deposit HALF their tokens into the exchange
    // -----

    // User1 approves 5,000 IPT...
    transaction = await ipt.connect(user1).approve(exchange.getAddress(), tokens(5000));
    await transaction.wait();
    console.log(`Approved 5000 IPT from ${user1.address}`);

    // User 1 deposits 5,000 IPT (keeps 5,000 in wallet)
    transaction = await exchange.connect(user1).depositToken(IPT_ADDRESS, tokens(5000));
    await transaction.wait();
    console.log(`Deposited 5000 IPT from ${user1.address}\n`);

    // User1 approves 5,000 mUSDC...
    transaction = await musdc.connect(user1).approve(await exchange.getAddress(), tokens(5000));
    await transaction.wait();
    console.log(`Approved 5000 mUSDC from ${user1.address}`);

    // User 1 deposits 5,000 mUSDC (keeps 5,000 in wallet)
    transaction = await exchange.connect(user1).depositToken(mUSDC_ADDRESS, tokens(5000));
    await transaction.wait();
    console.log(`Deposited 5000 mUSDC from ${user1.address}\n`);

    // User2 approves 5,000 mUSDC...
    transaction = await musdc.connect(user2).approve(await exchange.getAddress(), tokens(5000));
    await transaction.wait();
    console.log(`Approved 5000 mUSDC from ${user2.address}`);

    // User 2 deposits 5,000 mUSDC (keeps 5,000 in wallet)
    transaction = await exchange.connect(user2).depositToken(mUSDC_ADDRESS, tokens(5000));
    await transaction.wait();
    console.log(`Deposited 5000 mUSDC from ${user2.address}\n`);

    // User2 approves 5,000 IPT...
    transaction = await ipt.connect(user2).approve(await exchange.getAddress(), tokens(5000));
    await transaction.wait();
    console.log(`Approved 5000 IPT from ${user2.address}`);

    // User 2 deposits 5,000 IPT (keeps 5,000 in wallet)
    transaction = await exchange.connect(user2).depositToken(IPT_ADDRESS, tokens(5000));
    await transaction.wait();
    console.log(`Deposited 5000 IPT from ${user2.address}\n`);
    
    // -----
    // Cancel some orders
    // -----

    // User 1 makes order to get tokens
    let orderId;
    transaction = await exchange.connect(user1).makeOrder(mUSDC_ADDRESS, tokens(1), IPT_ADDRESS, tokens(1));
    result = await transaction.wait();
    console.log(`Made order from ${user1.address}`);

    // Get the orderId from the transaction receipt logs
    orderId = result.logs[0].args.id;

    // User 1 cancels order
    transaction = await exchange.connect(user1).cancelOrder(orderId);
    result = await transaction.wait();
    console.log(`Cancelled order from ${user1.address}\n`);

    // wait
    await wait(1);

    // Fill some orders
    // 3 times...
    for (var i = 1; i <= 3; i++) { 
        transaction = await exchange.connect(user1).makeOrder(mUSDC_ADDRESS, tokens(10 * i), IPT_ADDRESS, tokens(10));
        result = await transaction.wait();

        console.log(`Made order from ${user1.address}`);

        //User 2 fills order
        orderId = result.logs[0].args.id;
        transaction = await exchange.connect(user2).fillOrder(orderId);
        result = await transaction.wait();
        console.log(`Filled order from ${user2.address}\n`);

        // Wait 1 second
        await wait(1);
    }

    // -----
    // Seed some open orders
    // -----

    // User 1 makes 5 orders
    // User 1 wants to sell IPT for mUSDC
    for (var i = 1; i <= 5; i++) { 
        transaction = await exchange.connect(user1).makeOrder(mUSDC_ADDRESS, tokens(10 * i), IPT_ADDRESS, tokens(10));
        result = await transaction.wait();

        console.log(`Made order from ${user1.address}`);

        // Wait 1 second
        await wait(1);
    }

    // User 2 makes 5 orders
    // User 2 wants to sell mUSDC for IPT
    for (let i = 1; i <= 5; i++) { 
        transaction = await exchange.connect(user2).makeOrder(IPT_ADDRESS, tokens(10), mUSDC_ADDRESS, tokens(10 * i));
        result = await transaction.wait();

        console.log(`Made order from ${user2.address}`);

        // Wait 1 second
        await wait(1);
    }

    //-----
    // Perform some flash loans
    //-----

    for (let i = 0; i <=3; i++) {
        transaction = await flashLoanUser.connect(user1).getFlashLoan(IPT_ADDRESS, tokens(1000));
        result = await transaction.wait();

        console.log(`Flash loan executed from ${user1.address}`);

        // Wait 1 second
        await wait(1);
    }
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});