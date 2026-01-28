import { describe, expect, it, beforeAll } from 'vitest';
import { createAztecNodeClient, waitForNode } from '@aztec/aztec.js/node';
import { AztecAddress } from '@aztec/aztec.js/addresses';
import { Fr } from '@aztec/aztec.js/fields';
import { TestWallet, registerInitialLocalNetworkAccountsInWallet } from '@aztec/test-wallet/server';
import { DarkForestContract } from '../src/artifacts/DarkForest.js';

const NODE_URL = process.env.AZTEC_NODE_URL || 'http://localhost:8080';

const TEST_TIMEOUT = 120000;

describe('DarkForest Contract Integration', () => {
  let wallet: TestWallet;
  let admin: AztecAddress;
  let player: AztecAddress;
  let darkForest: DarkForestContract;

  beforeAll(async () => {
    // 1. Connect to local Aztec Node
    console.log(`Connecting to Aztec Node at ${NODE_URL}...`);
    const node = createAztecNodeClient(NODE_URL);
    await waitForNode(node);
    console.log('Node connected.');

    // 2. Create a TestWallet (manages keys and signing)
    wallet = await TestWallet.create(node);

    // 3. Load pre-funded accounts from the local network
    console.log('Loading pre-funded accounts...');
    const accounts = await registerInitialLocalNetworkAccountsInWallet(wallet);
    if (accounts.length < 2) {
      throw new Error('Need at least 2 accounts for testing');
    }
    admin = accounts[0];
    player = accounts[1];
    console.log(`Admin Address: ${admin.toString()}`);
    console.log(`Player Address: ${player.toString()}`);
  }, TEST_TIMEOUT);

  it(
    'should deploy the contract',
    async () => {
      const worldRadius = 1000n;
      const planetHashKey = Fr.random();
      const spaceTypeKey = Fr.random();
      const perlinLengthScale = 100n;
      const initPerlinMin = 10n;
      const initPerlinMax = 20n;

      console.log('Deploying contract...');
      // Standard deployment pattern from docs
      darkForest = await DarkForestContract.deploy(
        wallet,
        admin, // admin address argument
        worldRadius,
        planetHashKey,
        spaceTypeKey,
        perlinLengthScale,
        initPerlinMin,
        initPerlinMax
      )
        .send({ from: admin }) // transaction sender
        .deployed();

      expect(darkForest.address).toBeDefined();
      console.log(`Contract deployed at ${darkForest.address}`);
    },
    TEST_TIMEOUT
  );

  it(
    'should initialize a player',
    async () => {
      const x = new Fr(100);
      const y = new Fr(200);

      console.log('Initializing player...');
      // Transaction pattern: .send({ from }).wait()
      const tx = await darkForest.methods.initialize_player(x, y).send({ from: player }).wait();

      expect(tx.status).toBe('success'); // or TxStatus.SUCCESS if imported
      console.log(`Player initialized in tx: ${tx.txHash}`);
    },
    TEST_TIMEOUT
  );

  it(
    'should get player home planet',
    async () => {
      console.log('Fetching home planet...');
      // View/Simulate pattern: .simulate({ from })
      const homePlanet = await darkForest.methods
        .get_player_home_planet(player)
        .simulate({ from: player });

      console.log('Home planet ID:', homePlanet);
      expect(homePlanet).toBeDefined();
      // Since it's a field, it might be BigInt or Field-like.
      // Based on artifact, it returns a Field.
      // We can check if it's not zero if we expect it to be set.
    },
    TEST_TIMEOUT
  );

  it(
    'should get game config',
    async () => {
      console.log('Fetching game config...');
      const config = await darkForest.methods.get_game_config().simulate({ from: admin });
      const worldRadius = await darkForest.methods.get_world_radius().simulate({ from: admin });

      console.log('Game config:', config);
      console.log('World radius:', worldRadius);
      expect(config).toBeDefined();
      expect(worldRadius).toBe(1000n);
    },
    TEST_TIMEOUT
  );
});
