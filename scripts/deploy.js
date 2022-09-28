// scripts/deploy.js

const hre = require("hardhat");

async function main() {
    // We get the contract to deploy.
    const Casino2 = await hre.ethers.getContractFactory("Casino2");
    const casino = await Casino2.deploy();

    await casino.deployed();

    console.log("Casino2 deployed to:", casino.address);
}


// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });