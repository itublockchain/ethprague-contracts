async function main() {
    // We get the contract to deploy
    const Marketplace = await ethers.getContractFactory("Marketplace");
    const marketplace = await Marketplace.deploy("0xc662c410C0ECf747543f5bA90660f6ABeBD9C8c4");
  
    await marketplace.deployed();
  
    console.log("Marketplace deployed to:", marketplace.address);
  }
  
  main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });