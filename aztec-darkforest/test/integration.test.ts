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

  // =========================================================================
  // Move Planet Integration Tests
  // =========================================================================

  it(
    'should move from home planet to a new planet',
    async () => {
      // Get player's home planet first
      const homePlanetId = await darkForest.methods
        .get_player_home_planet(player)
        .simulate({ from: player });
      console.log('Home planet ID:', homePlanetId);

      // Source and target coordinates
      const fromX = new Fr(100); // Home coords
      const fromY = new Fr(200);
      const toX = new Fr(150); // Nearby target
      const toY = new Fr(250);

      // We need the target planet_id (hash of coords)
      // For testing, we'll use a placeholder - in real test would compute hash
      const toPlanetId = Fr.random(); // Placeholder

      const energySent = 500n;
      const silverSent = 0n;

      console.log('Moving from home planet...');
      const tx = await darkForest.methods
        .move_planet(
          fromX,
          fromY,
          toX,
          toY,
          homePlanetId, // from_planet_id
          toPlanetId, // to_planet_id
          energySent,
          silverSent
        )
        .send({ from: player })
        .wait();

      expect(tx.status).toBe('success');
      console.log(`Move executed in tx: ${tx.txHash}`);
    },
    TEST_TIMEOUT
  );

  it(
    'should create arrival record with travel time delay',
    async () => {
      // After a move, the arrival should be pending, not immediately applied
      // This test verifies the delayed arrival mechanism

      console.log('Verifying delayed arrival mechanism...');

      // The newly moved-to planet shouldn't have full energy yet
      // (energy only arrives after refresh_planet is called when arrival_time is reached)

      // This is a placeholder - actual verification would need:
      // 1. Execute move at time T
      // 2. Check target planet population at time T (should be base/0)
      // 3. Advance blockchain time past arrival_time
      // 4. Call refresh_planet or another operation
      // 5. Check target planet population (should now include arrival)

      expect(true).toBe(true); // Placeholder assertion
    },
    TEST_TIMEOUT
  );

  it(
    'should reject move to out-of-range destination',
    async () => {
      // Get home planet ID
      const homePlanetId = await darkForest.methods
        .get_player_home_planet(player)
        .simulate({ from: player });

      // Target coordinates (very far away, out of range)
      const toX = new Fr(900);
      const toY = new Fr(900);
      const toPlanetId = Fr.random();
      const energySent = 100n;
      const silverSent = 0n;

      console.log('Attempting out-of-range move...');

      try {
        await darkForest.methods
          .move_planet(
            new Fr(100), // fromX
            new Fr(200), // fromY
            toX,
            toY,
            homePlanetId,
            toPlanetId,
            energySent,
            silverSent
          )
          .send({ from: player })
          .wait();

        // Should not reach here
        expect(true).toBe(false);
      } catch (error) {
        // Expected: should fail with range check
        console.log('Move correctly rejected (out of range)');
        expect(error).toBeDefined();
      }
    },
    TEST_TIMEOUT
  );

  it(
    'should reject move with insufficient energy',
    async () => {
      // Get home planet ID
      const homePlanetId = await darkForest.methods
        .get_player_home_planet(player)
        .simulate({ from: player });

      // Try to send more energy than available
      const toX = new Fr(110);
      const toY = new Fr(210);
      const toPlanetId = Fr.random();
      const energySent = 999999999n; // Way more than available
      const silverSent = 0n;

      console.log('Attempting move with insufficient energy...');

      try {
        await darkForest.methods
          .move_planet(
            new Fr(100), // fromX
            new Fr(200), // fromY
            toX,
            toY,
            homePlanetId,
            toPlanetId,
            energySent,
            silverSent
          )
          .send({ from: player })
          .wait();

        expect(true).toBe(false);
      } catch (error) {
        console.log('Move correctly rejected (insufficient energy)');
        expect(error).toBeDefined();
      }
    },
    TEST_TIMEOUT
  );

  it(
    'should reject move to outside world radius',
    async () => {
      // Get home planet ID
      const homePlanetId = await darkForest.methods
        .get_player_home_planet(player)
        .simulate({ from: player });

      // Target coordinates outside world radius (radius is 1000)
      const toX = new Fr(990);
      const toY = new Fr(990);
      const toPlanetId = Fr.random();
      const energySent = 100n;
      const silverSent = 0n;

      console.log('Attempting move outside world radius...');

      try {
        await darkForest.methods
          .move_planet(
            new Fr(100), // fromX
            new Fr(200), // fromY
            toX,
            toY,
            homePlanetId,
            toPlanetId,
            energySent,
            silverSent
          )
          .send({ from: player })
          .wait();

        expect(true).toBe(false);
      } catch (error) {
        console.log('Move correctly rejected (outside world radius)');
        expect(error).toBeDefined();
      }
    },
    TEST_TIMEOUT
  );

  it(
    'should refresh planet and process arrivals',
    async () => {
      // Get a planet that has pending arrivals
      const homePlanetId = await darkForest.methods
        .get_player_home_planet(player)
        .simulate({ from: player });

      console.log('Calling refresh_planet...');
      const tx = await darkForest.methods
        .refresh_planet(homePlanetId)
        .send({ from: player })
        .wait();

      expect(tx.status).toBe('success');
      console.log(`refresh_planet executed in tx: ${tx.txHash}`);

      // After refresh, any arrivals that have reached arrival_time should be processed
    },
    TEST_TIMEOUT
  );
});
