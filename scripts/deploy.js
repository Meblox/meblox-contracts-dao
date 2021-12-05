async function main() {
    const [deployer] = await ethers.getSigners();
  
    console.log("Deploying contracts with the account:", deployer.address);
  
    console.log("Account balance:", (await deployer.getBalance()).toString());

    const contractFactory = await ethers.getContractFactory("MebloxDAO"); // MebloxDAO 为合约名
    const contract = await contractFactory.deploy();
  
    console.log("MebloxDAO contract address:", contract.address);
  }
  
  main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });