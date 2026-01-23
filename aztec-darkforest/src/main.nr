// Module declarations
mod types;
mod notes;
mod utils;
mod planet;
mod player;
mod artifact;

use aztec::macros::aztec;

#[aztec]
pub contract DarkForest {
    use aztec::{
        protocol_types::address::AztecAddress,
        macros::{functions::{external, initializer, internal, view, only_self}, storage::storage, events::event},
        state_vars::{public_mutable::PublicMutable, public_immutable::PublicImmutable, Map},
    };

    // Import utility functions
    use crate::utils::hash::compute_planet_hash;
    use crate::utils::perlin::compute_perlin;

    // =========================================================================
    // Events
    // =========================================================================
    #[event]
    struct PlayerInitialized {
        player: AztecAddress,
        home_planet: Field,
    }

    #[event]
    struct PlanetMoved {
        from: Field,
        to: Field,
        owner: AztecAddress,
        distance: u64,
    }

    #[event]
    struct LocationRevealed {
        planet_id: Field,
        x: Field,
        y: Field,
        revealer: AztecAddress,
    }

    #[event]
    struct PlanetUpgraded {
        planet_id: Field,
        branch: u8,
        new_level: u8,
    }

    #[event]
    struct ArtifactFound {
        planet_id: Field,
        artifact_id: Field,
        artifact_type: u8,
        rarity: u8,
        discoverer: AztecAddress,
    }

    // =========================================================================
    // Storage Structure
    // =========================================================================
    #[storage]
    struct Storage<Context> {
        // Admin
        admin: PublicMutable<AztecAddress, Context>,
        paused: PublicMutable<bool, Context>,

        // Game Configuration
        world_radius: PublicImmutable<u64, Context>,
        planethash_key: PublicImmutable<Field, Context>,
        spacetype_key: PublicImmutable<Field, Context>,
        perlin_length_scale: PublicImmutable<u64, Context>,

        // Initialization bounds (perlin range for spawning)
        init_perlin_min: PublicImmutable<u64, Context>,
        init_perlin_max: PublicImmutable<u64, Context>,

        // Perlin thresholds for space types
        perlin_threshold_1: PublicImmutable<u64, Context>,
        perlin_threshold_2: PublicImmutable<u64, Context>,
        perlin_threshold_3: PublicImmutable<u64, Context>,

        // Counters
        planet_count: PublicMutable<u64, Context>,
        player_count: PublicMutable<u64, Context>,
        artifact_count: PublicMutable<u64, Context>,

        // Artifacts
        artifacts: Map<Field, PublicMutable<crate::types::artifact::ArtifactState, Context>, Context>,
        planet_artifact: Map<Field, PublicMutable<Field, Context>, Context>,

        // Player tracking: address => home_planet_id (0 = not initialized)
        player_home_planets: Map<AztecAddress, PublicMutable<Field, Context>, Context>,

        // Planet tracking: Full state storage
        planets: Map<Field, PublicMutable<crate::types::planet::PlanetPublicState, Context>, Context>,

        // Revealed Coordinates (split for simpler storage)
        revealed_x: Map<Field, PublicMutable<Field, Context>, Context>,
        revealed_y: Map<Field, PublicMutable<Field, Context>, Context>,
        revealed_revealer: Map<Field, PublicMutable<AztecAddress, Context>, Context>,

        // Player cooldowns
        player_last_reveal: Map<AztecAddress, PublicMutable<u64, Context>, Context>,
    }

    // =========================================================================
    // Constructor
    // =========================================================================

    /// Initialize the Dark Forest contract
    ///
    /// # Arguments
    /// * `admin` - Admin address for pausing/unpausing
    /// * `world_radius` - Radius of the game world
    /// * `planethash_key` - MiMC key for planet hash
    /// * `spacetype_key` - Key for perlin noise
    /// * `perlin_length_scale` - Scale for perlin noise (e.g., 8192)
    /// * `init_perlin_min` - Minimum perlin for spawning
    /// * `init_perlin_max` - Maximum perlin for spawning
    #[external("public")]
    #[initializer]
    fn constructor(
        admin: AztecAddress,
        world_radius: u64,
        planethash_key: Field,
        spacetype_key: Field,
        perlin_length_scale: u64,
        init_perlin_min: u64,
        init_perlin_max: u64,
    ) {
        // Admin and state
        self.storage.admin.write(admin);
        self.storage.paused.write(false);

        // Game config
        self.storage.world_radius.initialize(world_radius);
        self.storage.planethash_key.initialize(planethash_key);
        self.storage.spacetype_key.initialize(spacetype_key);
        self.storage.perlin_length_scale.initialize(perlin_length_scale);

        // Initialization bounds
        self.storage.init_perlin_min.initialize(init_perlin_min);
        self.storage.init_perlin_max.initialize(init_perlin_max);

        // Default perlin thresholds for space types
        self.storage.perlin_threshold_1.initialize(11);
        self.storage.perlin_threshold_2.initialize(13);
        self.storage.perlin_threshold_3.initialize(15);

        // Counters
        self.storage.planet_count.write(0);
        self.storage.player_count.write(0);
        self.storage.artifact_count.write(0);
        self.storage.artifact_count.write(0);
    }

    // =========================================================================
    // Player Initialization (Private Entry Point)
    // =========================================================================

    /// Initialize a new player at the given coordinates
    ///
    /// This is a PRIVATE function - the x, y coordinates are never revealed on-chain.
    /// The Aztec protocol automatically generates a ZK proof that the coordinates
    /// are valid without revealing what they are.
    ///
    /// NOTE: Configuration parameters must be passed in because private functions
    /// cannot directly read public storage.
    ///
    /// # Arguments
    /// * `x` - Private X coordinate of home planet
    /// * `y` - Private Y coordinate of home planet
    /// * `planethash_key` - MiMC key for hashing (from public config)
    /// * `spacetype_key` - Key for perlin (from public config)
    /// * `perlin_scale` - Perlin scale (from public config)
    /// * `world_radius` - World boundary (from public config)
    /// * `init_perlin_min` - Min spawn perlin (from public config)
    /// * `init_perlin_max` - Max spawn perlin (from public config)
    ///
    /// # Returns
    /// * The planet ID (hash of coordinates) - this IS public
    #[external("private")]
    fn initialize_player(
        x: Field,
        y: Field,
    ) -> pub Field {
        // Read config from PublicImmutable
        let planethash_key = self.storage.planethash_key.read();
        let world_radius = self.storage.world_radius.read();
        let spacetype_key = self.storage.spacetype_key.read();
        let perlin_scale = self.storage.perlin_length_scale.read();
        let init_perlin_min = self.storage.init_perlin_min.read();
        let init_perlin_max = self.storage.init_perlin_max.read();

        // 1. Compute planet_id = MiMC(x, y, key)
        let planet_id = compute_planet_hash(x, y, planethash_key);

        // 2. Validate coordinates within world bounds
        // Note: x * x + y * y < radius^2
        let world_radius_field = world_radius as Field;
        let dist_squared = x * x + y * y;
        let radius_squared = world_radius_field * world_radius_field;
        // Field comparison requires casting
        assert(
            (dist_squared as u64) < (radius_squared as u64),
            "Coordinates out of world bounds"
        );

        // 3. Compute perlin value at coordinates
        let perlin = compute_perlin(x, y, spacetype_key, perlin_scale);

        // 4. Validate perlin is within spawn range
        assert(perlin >= init_perlin_min, "Perlin value too low for spawn");
        assert(perlin < init_perlin_max, "Perlin value too high for spawn");

        // 5. Get sender address for callback
        let sender = self.context.msg_sender().unwrap();

        // 6. Enqueue public callback to update on-chain state
        // The public function will validate that player/planet doesn't exist
        self.enqueue_self.initialize_player_callback(planet_id, perlin, sender);

        // 6. Return the planet_id (public output)
        planet_id
    }

    // =========================================================================
    // Player Initialization (Internal Callback)
    // =========================================================================

    /// Note: The sender parameter is passed from enqueue_self context
    #[external("public")]
    #[only_self]
    fn initialize_player_callback(planet_id: Field, perlin: u64, sender: AztecAddress) {

        // 1. Check game is not paused
        assert(!self.storage.paused.read(), "Game is paused");

        // 2. Check player not already initialized (home_planet != 0)
        let existing_home = self.storage.player_home_planets.at(sender).read();
        assert(existing_home == 0, "Player already initialized");

        // 3. Check planet not already taken
        // We check if planet_id exists in planets map by checking owner/init status
        // But since Map keys always exist with default values, we check owner.
        // However, we changed storage to PlanetPublicState, so we read the struct.
        let existing_planet = self.storage.planets.at(planet_id).read();
        assert(existing_planet.owner == AztecAddress::zero(), "Planet already taken");

        // 4. Calculate Space Type
        let t1 = self.storage.perlin_threshold_1.read();
        let t2 = self.storage.perlin_threshold_2.read();
        let t3 = self.storage.perlin_threshold_3.read();
        let space_type = crate::types::enums::get_space_type_from_perlin(perlin, t1, t2, t3);

        // 5. Determine Planet Level
        // Note: Default to level 1 for home planets for MVP. Verify thresholds in future.
        let level = 1;

        // 6. Create Initial Planet State
        let timestamp = self.context.timestamp();
        let new_planet = crate::planet::init::create_initial_planet(
            planet_id,
            sender,
            level,
            space_type,
            perlin,
            true, // is_home_planet
            timestamp
        );

        // 7. Store Planet
        self.storage.planets.at(planet_id).write(new_planet);

        // 8. Store player's home planet
        self.storage.player_home_planets.at(sender).write(planet_id);

        // 9. Store planet perlin separately if needed for other checks,
        // but it is now in PlanetPublicState. Keeping the separate map for now
        // as per Storage definition, or should I remove it?
        // I removed it in previous step! So no need to write.

        // 10. Increment counters
        let player_count = self.storage.player_count.read();
        self.storage.player_count.write(player_count + 1);

        let planet_count = self.storage.planet_count.read();
        self.storage.planet_count.write(planet_count + 1);

        // Emit Event
        self.context.emit_public_log(
            PlayerInitialized {
                player: sender,
                home_planet: planet_id,
            }
        );
    }

    // =========================================================================
    // Planet Movement (Private Entry Point)
    // =========================================================================

    /// Move energy and silver from one planet to another
    ///
    /// This is a PRIVATE function - the coordinates are never revealed on-chain.
    /// The Aztec protocol automatically generates a ZK proof.
    ///
    /// # Arguments
    /// * `from_x`, `from_y` - Private source coordinates
    /// * `to_x`, `to_y` - Private destination coordinates
    /// * `from_planet_id`, `to_planet_id` - Public planet IDs (hashes)
    /// * `energy_sent` - Amount of energy to send
    /// * `silver_sent` - Amount of silver to send
    /// * `planethash_key` - MiMC key for verification
    #[external("private")]
    fn move_planet(
        from_x: Field,
        from_y: Field,
        to_x: Field,
        to_y: Field,
        from_planet_id: Field,
        to_planet_id: Field,
        energy_sent: u64,
        silver_sent: u64,
    ) {
        // Read config from PublicImmutable
        let planethash_key = self.storage.planethash_key.read();
        let spacetype_key = self.storage.spacetype_key.read();
        let perlin_scale = self.storage.perlin_length_scale.read();

        // 1. Verify coordinate hashes match planet IDs
        let computed_from = compute_planet_hash(from_x, from_y, planethash_key);
        let computed_to = compute_planet_hash(to_x, to_y, planethash_key);
        assert(computed_from == from_planet_id, "Invalid from coordinates");
        assert(computed_to == to_planet_id, "Invalid to coordinates");

        // 2. Get sender
        let sender = self.context.msg_sender().unwrap();

        // 3. Calculate distance (convert Field to i64 for distance calculation)
        let from_x_i64 = from_x as i64;
        let from_y_i64 = from_y as i64;
        let to_x_i64 = to_x as i64;
        let to_y_i64 = to_y as i64;
        let distance = crate::planet::move_planet::calculate_distance(
            from_x_i64, from_y_i64, to_x_i64, to_y_i64
        );

        // 4. Calculate destination perlin (needed for initialization if new)
        let to_perlin = crate::utils::perlin::compute_perlin(to_x, to_y, spacetype_key, perlin_scale);

        // 5. Enqueue public callback to process the move
        self.enqueue_self.move_callback(
            from_planet_id,
            to_planet_id,
            energy_sent,
            silver_sent,
            distance,
            to_perlin,
            sender
        );
    }

    // =========================================================================
    // Planet Movement (Public Callback)
    // =========================================================================

    /// Process a planet movement
    ///
    /// Validates ownership and updates planet states
    #[external("public")]
    #[only_self]
    fn move_callback(
        from_planet_id: Field,
        to_planet_id: Field,
        energy_sent: u64,
        silver_sent: u64,
        distance: u64,
        to_perlin: u64,
        sender: AztecAddress,
    ) {
        // 1. Check game is not paused
        assert(!self.storage.paused.read(), "Game is paused");

        // 2. Verify sender owns the source planet and it is initialized
        let mut from_planet = self.storage.planets.at(from_planet_id).read();
        assert(from_planet.owner == sender, "Not planet owner");
        assert(from_planet.is_initialized, "Source planet not initialized");

        // ---------------------------------------------------------
        // Refresh Source Planet with Artifacts
        // ---------------------------------------------------------
        let from_artifact_id = self.storage.planet_artifact.at(from_planet_id).read();
        let mut from_artifact_type = 0;
        if from_artifact_id != 0 {
             let art = self.storage.artifacts.at(from_artifact_id).read();
             from_artifact_type = art.artifact_type;
        }

        let (src_range, _, _, src_pop_cap, src_pop_growth, src_silver_cap, src_silver_growth) =
            crate::planet::state::get_effective_stats(
                from_planet.range, from_planet.speed, from_planet.defense,
                from_planet.population_cap, from_planet.population_growth,
                from_planet.silver_cap, from_planet.silver_growth,
                from_planet.upgrade_state_0, from_planet.upgrade_state_1, from_planet.upgrade_state_2,
                from_planet.hat_level, from_artifact_type
            );

        let timestamp = self.context.timestamp();
        from_planet = crate::planet::state::refresh_planet_state(
            from_planet, timestamp,
            src_pop_cap, src_pop_growth, src_silver_cap, src_silver_growth
        );

        // Verify range
        assert(distance <= src_range, "Destination out of range");

        // Deduct energy and silver
        assert(from_planet.population >= energy_sent, "Insufficient energy");
        assert(from_planet.silver >= silver_sent, "Insufficient silver");

        from_planet.population -= energy_sent;
        from_planet.silver -= silver_sent;

        // Write back source planet
        self.storage.planets.at(from_planet_id).write(from_planet);

        // ---------------------------------------------------------
        // Destination Planet Logic (Arrival)
        // ---------------------------------------------------------

        // Initialize if empty
        let mut to_planet = self.storage.planets.at(to_planet_id).read();
        if !to_planet.is_initialized {
            let t1 = self.storage.perlin_threshold_1.read();
            let t2 = self.storage.perlin_threshold_2.read();
            let t3 = self.storage.perlin_threshold_3.read();
            let space_type = crate::types::enums::get_space_type_from_perlin(to_perlin, t1, t2, t3);

            to_planet = crate::planet::init::create_unowned_planet(
                to_planet_id, 0, space_type, to_perlin, timestamp
            );
            self.storage.planet_count.write(self.storage.planet_count.read() + 1);
        }

        // Refresh Destination
        let to_artifact_id = self.storage.planet_artifact.at(to_planet_id).read();
        let mut to_artifact_type = 0;
        if to_artifact_id != 0 {
             let art = self.storage.artifacts.at(to_artifact_id).read();
             to_artifact_type = art.artifact_type;
        }

        let (_, _, dest_defense, dest_pop_cap, dest_pop_growth, dest_silver_cap, dest_silver_growth) =
            crate::planet::state::get_effective_stats(
                to_planet.range, to_planet.speed, to_planet.defense,
                to_planet.population_cap, to_planet.population_growth,
                to_planet.silver_cap, to_planet.silver_growth,
                to_planet.upgrade_state_0, to_planet.upgrade_state_1, to_planet.upgrade_state_2,
                to_planet.hat_level, to_artifact_type
            );

        to_planet = crate::planet::state::refresh_planet_state(
            to_planet, timestamp,
            dest_pop_cap, dest_pop_growth, dest_silver_cap, dest_silver_growth
        );

        // Apply Arrival Logic
        // Simple instant arrival (no decay for MVP)
        let arriving_energy = energy_sent;

        if to_planet.owner == sender {
            // Reinforce
            let mut new_pop = to_planet.population + arriving_energy;
            if new_pop > dest_pop_cap { new_pop = dest_pop_cap; }
            to_planet.population = new_pop;

            let mut new_silver = to_planet.silver + silver_sent;
            if new_silver > dest_silver_cap { new_silver = dest_silver_cap; }
            to_planet.silver = new_silver;
        } else {
            // Attack
            // Defense bonus applies to population
            let effective_defense_pop = (to_planet.population * dest_defense) / 100;

            if arriving_energy > effective_defense_pop {
                // Conquered!
                to_planet.owner = sender;
                to_planet.population = arriving_energy - effective_defense_pop;
                // Cap? Usually conquest sets low pop?
                if to_planet.population > dest_pop_cap { to_planet.population = dest_pop_cap; }

                // Loot silver? Usually percentage
                to_planet.silver = to_planet.silver / 2; // simplified looot
            } else {
                // Defended
                let damage = (arriving_energy * 100) / dest_defense;
                if damage > to_planet.population {
                    to_planet.population = 0;
                } else {
                    to_planet.population -= damage;
                }
            }
        }

        self.storage.planets.at(to_planet_id).write(to_planet);

        self.context.emit_public_log(
            PlanetMoved {
                from: from_planet_id,
                to: to_planet_id,
                owner: sender,
                distance: distance,
            }
        );
    }

    // =========================================================================
    // Planet Upgrades
    // =========================================================================

    /// Upgrade a planet's stats
    ///
    /// # Arguments
    /// * `planet_id` - The planet to upgrade
    /// * `branch` - The upgrade branch (0=Defense, 1=Range, 2=Speed)
    #[external("public")]
    #[only_self]
    fn upgrade_planet(planet_id: Field, branch: u8) {
        // 1. Check game is not paused
        assert(!self.storage.paused.read(), "Game is paused");

        // 2. Verify ownership and initialization
        let mut planet = self.storage.planets.at(planet_id).read();
        let sender = self.context.msg_sender().unwrap();
        assert(planet.owner == sender, "Not planet owner");
        assert(planet.is_initialized, "Planet not initialized");

        // 3. Refresh state before checking resources (crucial!)
        let artifact_id = self.storage.planet_artifact.at(planet_id).read();
        let mut artifact_type = 0;
        if artifact_id != 0 {
             let art = self.storage.artifacts.at(artifact_id).read();
             artifact_type = art.artifact_type;
        }

        let (_, _, _, pop_cap, pop_growth, silver_cap, silver_growth) =
            crate::planet::state::get_effective_stats(
                planet.range, planet.speed, planet.defense,
                planet.population_cap, planet.population_growth,
                planet.silver_cap, planet.silver_growth,
                planet.upgrade_state_0, planet.upgrade_state_1, planet.upgrade_state_2,
                planet.hat_level, artifact_type
            );

        let timestamp = self.context.timestamp();
        planet = crate::planet::state::refresh_planet_state(
            planet, timestamp,
            pop_cap, pop_growth, silver_cap, silver_growth
        );

        // 4. Determine current upgrade level for branch
        let mut current_level = 0;
        if branch == 0 {
            current_level = planet.upgrade_state_0;
        } else if branch == 1 {
            current_level = planet.upgrade_state_1;
        } else if branch == 2 {
            current_level = planet.upgrade_state_2;
        } else {
            assert(false, "Invalid upgrade branch");
        }

        // 5. Check if upgradeable
        assert(crate::planet::state::can_upgrade_planet(planet.level, current_level), "Cannot upgrade");

        // 6. Calculate cost
        let cost = crate::planet::state::get_upgrade_cost(planet.level, current_level);
        assert(planet.silver >= cost, "Insufficient silver");

        // 7. Deduct cost and apply upgrade
        planet.silver -= cost;
        if branch == 0 {
            planet.upgrade_state_0 += 1;
        } else if branch == 1 {
            planet.upgrade_state_1 += 1;
        } else if branch == 2 {
            planet.upgrade_state_2 += 1;
        }

        // 8. Update effective stats (optional, but good for views if stats stored)
        // Currently range/speed/defense are stored as base stats in struct?
        // Wait, `PlanetPublicState` has `range`, `speed`, `defense` fields.
        // `create_initial_planet` sets them to defaults.
        // `get_effective_stats` calculates effective stats from base + upgrades.
        // We should probably NOT update base stats in storage, but we might want to cache effective stats?
        // The current `PlanetPublicState` seems to store *Base* stats or *Effective* stats?
        // `init.nr`: `range: stats.range`.
        // `state.nr`: `get_effective_stats` takes `base_range`.
        // If `PlanetPublicState.range` stores CURRENT effective range, we should update it here.
        // If it stores BASE range, we shouldn't touch it.
        // Let's assume it stores BASE for now to be safe, or check init.nr.
        // `init.nr` sets `range = stats.range`.
        // If we want `get_planet_range` view to return effective value, it should call `get_effective_stats`.

        // Let's update the stored stats to be effective stats?
        // No, that makes "un-upgrading" or recalculating hard if logic changes.
        // Better to verify what `PlanetPublicState` holds.
        // Usually it holds everything needed.

        // For now, I will just update the `upgrade_state_X`.
        // View functions will be responsible for applying multipliers.

        // Write back
        self.storage.planets.at(planet_id).write(planet);

        // Emit Event
        self.context.emit_public_log(
            PlanetUpgraded {
                planet_id: planet_id,
                branch: branch,
                new_level: current_level + 1,
            }
        );
    }
    // =========================================================================
    // Artifact Discovery
    // =========================================================================

    /// Search for an artifact on a planet
    ///
    /// # Arguments
    /// * `x`, `y` - Private coordinates
    /// * `planet_id` - Planet to search on
    #[external("private")]
    fn find_artifact(
        x: Field,
        y: Field,
        planet_id: Field
    ) {
        // Read config
        let planethash_key = self.storage.planethash_key.read();

        // 1. Verify hash
        let computed = compute_planet_hash(x, y, planethash_key);
        assert(computed == planet_id, "Invalid coordinates");

        // 2. Get sender
        let sender = self.context.msg_sender().unwrap();

        // 3. Enqueue public callback
        self.enqueue_self.find_artifact_callback(planet_id, sender);
    }

    /// Process artifact discovery
    ///
    /// Validates cost and randomness
    #[external("public")]
    #[only_self]
    fn find_artifact_callback(
        planet_id: Field,
        sender: AztecAddress
    ) {
        // 1. Check game is not paused
        assert(!self.storage.paused.read(), "Game is paused");

        // 2. Verify ownership and initialization
        let mut planet = self.storage.planets.at(planet_id).read();
        assert(planet.owner == sender, "Not planet owner");
        assert(planet.is_initialized, "Planet not initialized");
        assert(!planet.has_tried_finding_artifact, "Already searched this planet");

        // 3. Refresh state
        // Initial find: No artifact yet
        let (_, _, _, pop_cap, pop_growth, silver_cap, silver_growth) =
            crate::planet::state::get_effective_stats(
                planet.range, planet.speed, planet.defense,
                planet.population_cap, planet.population_growth,
                planet.silver_cap, planet.silver_growth,
                planet.upgrade_state_0, planet.upgrade_state_1, planet.upgrade_state_2,
                planet.hat_level, 0
            );

        let timestamp = self.context.timestamp();
        planet = crate::planet::state::refresh_planet_state(
            planet, timestamp,
            pop_cap, pop_growth, silver_cap, silver_growth
        );

        // 4. Calculate cost (50% of max population)
        let cost = planet.population_cap / 2;
        assert(planet.population >= cost, "Insufficient energy for prospecting");
        planet.population -= cost;

        // 5. Mark as searched
        planet.has_tried_finding_artifact = true;
        self.storage.planets.at(planet_id).write(planet);

        // 6. Check for artifact
        if crate::artifact::discovery::is_artifact_found(planet_id) {
            // Found! Mint artifact
            let rarity = crate::artifact::discovery::roll_rarity(planet_id);
            // We need space_type/biome for type rolling?
            // SpaceType is public logic? No, derived from Perlin.
            // But we don't have Perlin passed here. Storage has `current_perlin`.
            let planet_perlin = planet.perlin;

            // Get space type to influence artifact?
            // For now, allow roll regardless of biome, or use mock biome
            let artifact_type = crate::artifact::discovery::roll_artifact_type(planet_id, planet_perlin as u8);

            // Increment count for ID
            let mut count = self.storage.artifact_count.read();
            count += 1;
            self.storage.artifact_count.write(count);

            let new_artifact_id = count as Field; // Simple ID generation

            // Create Artifact
            let mut artifact = crate::types::artifact::ArtifactState::default();
            artifact.id = new_artifact_id;
            artifact.is_initialized = true;
            artifact.planet_discovered_on = planet_id;
            artifact.discoverer = sender;
            artifact.minted_at_timestamp = timestamp;
            artifact.artifact_type = artifact_type;
            artifact.rarity = rarity;

            // Link storage
            self.storage.artifacts.at(new_artifact_id).write(artifact);
            self.storage.planet_artifact.at(planet_id).write(new_artifact_id);

            // Emit Event
            self.context.emit_public_log(
                ArtifactFound {
                    planet_id: planet_id,
                    artifact_id: new_artifact_id,
                    artifact_type: artifact_type,
                    rarity: rarity,
                    discoverer: sender,
                }
            );
        }
    }

    // =========================================================================
    // Location Reveal
    // =========================================================================

    /// Reveal a planet's location publicly
    ///
    /// # Arguments
    /// * `x`, `y` - Private coordinates
    /// * `planet_id` - Public planet ID
    #[external("private")]
    fn reveal_location(
        x: Field,
        y: Field,
        planet_id: Field,
    ) {
        // Read config
        let planethash_key = self.storage.planethash_key.read();

        // 1. Verify hash
        let computed = compute_planet_hash(x, y, planethash_key);
        assert(computed == planet_id, "Invalid coordinates");

        // 2. Get sender
        let sender = self.context.msg_sender().unwrap();

        // 3. Enqueue public callback
        self.enqueue_self.reveal_callback(planet_id, x, y, sender);
    }

    /// Process location reveal
    ///
    /// Validates cooldown and updates revealed state
    #[external("public")]
    #[only_self]
    fn reveal_callback(
        planet_id: Field,
        x: Field,
        y: Field,
        sender: AztecAddress
    ) {
        // 1. Check cooldown (24 hours = 86400 seconds)
        let last_reveal = self.storage.player_last_reveal.at(sender).read();
        let current_time = self.context.timestamp();
        // Note: Check for underflow/first time (last_reveal could be 0)
        if last_reveal != 0 {
            assert(current_time >= last_reveal + 86400, "Reveal cooldown active");
        }

        // 2. Update revealed state
        self.storage.revealed_x.at(planet_id).write(x);
        self.storage.revealed_y.at(planet_id).write(y);
        self.storage.revealed_revealer.at(planet_id).write(sender);

        // 3. Update player cooldown
        self.storage.player_last_reveal.at(sender).write(current_time);

        // Emit Event
        self.context.emit_public_log(
            LocationRevealed {
                planet_id: planet_id,
                x: x,
                y: y,
                revealer: sender,
            }
        );
    }

    // =========================================================================
    // Admin Functions
    // =========================================================================

    /// Pause the game (admin only)
    #[external("public")]
    fn pause() {
        let sender = self.context.msg_sender().unwrap();
        assert(sender == self.storage.admin.read(), "Not admin");
        self.storage.paused.write(true);
    }

    /// Unpause the game (admin only)
    #[external("public")]
    fn unpause() {
        let sender = self.context.msg_sender().unwrap();
        assert(sender == self.storage.admin.read(), "Not admin");
        self.storage.paused.write(false);
    }

    // =========================================================================
    // View Functions
    // =========================================================================

    /// Check if game is paused
    #[external("public")]
    #[view]
    fn is_paused() -> pub bool {
        self.storage.paused.read()
    }

    /// Get world radius
    #[external("public")]
    #[view]
    fn get_world_radius() -> pub u64 {
        self.storage.world_radius.read()
    }

    /// Get planet count
    #[external("public")]
    #[view]
    fn get_planet_count() -> pub u64 {
        self.storage.planet_count.read()
    }

    /// Get player count
    #[external("public")]
    #[view]
    fn get_player_count() -> pub u64 {
        self.storage.player_count.read()
    }

    /// Get game configuration
    /// Returns: (planethash_key, spacetype_key, perlin_scale, init_min, init_max)
    #[external("public")]
    #[view]
    fn get_game_config() -> pub (Field, Field, u64, u64, u64) {
        (
            self.storage.planethash_key.read(),
            self.storage.spacetype_key.read(),
            self.storage.perlin_length_scale.read(),
            self.storage.init_perlin_min.read(),
            self.storage.init_perlin_max.read()
        )
    }

    // =========================================================================
    // Player Query Functions
    // =========================================================================

    /// Check if a player is initialized
    #[external("public")]
    #[view]
    fn is_player_initialized(player: AztecAddress) -> pub bool {
        self.storage.player_home_planets.at(player).read() != 0
    }

    /// Get a player's home planet ID
    /// Returns 0 if player is not initialized
    #[external("public")]
    #[view]
    fn get_player_home_planet(player: AztecAddress) -> pub Field {
        self.storage.player_home_planets.at(player).read()
    }

    // =========================================================================
    // Planet Query Functions
    // =========================================================================

    /// Get the owner of a planet
    /// Returns zero address if planet is not initialized
    #[external("public")]
    #[view]
    fn get_planet_owner(planet_id: Field) -> pub AztecAddress {
        self.storage.planets.at(planet_id).read().owner
    }

    /// Get the perlin value of a planet
    /// Used to determine space type
    #[external("public")]
    #[view]
    fn get_planet_perlin(planet_id: Field) -> pub u64 {
        self.storage.planets.at(planet_id).read().perlin
    }

    /// Check if a planet is initialized (has an owner or marked initialized)
    #[external("public")]
    #[view]
    fn is_planet_initialized(planet_id: Field) -> pub bool {
        self.storage.planets.at(planet_id).read().is_initialized
    }

    /// Get planet effective range
    #[external("public")]
    #[view]
    fn get_planet_range(planet_id: Field) -> pub u64 {
        let planet = self.storage.planets.at(planet_id).read();

        let artifact_id = self.storage.planet_artifact.at(planet_id).read();
        let mut artifact_type = 0;
        if artifact_id != 0 {
             let art = self.storage.artifacts.at(artifact_id).read();
             artifact_type = art.artifact_type;
        }

        let (eff_range, _, _, _, _, _, _) = crate::planet::state::get_effective_stats(
            planet.range, planet.speed, planet.defense,
            planet.population_cap, planet.population_growth,
            planet.silver_cap, planet.silver_growth,
            planet.upgrade_state_0, planet.upgrade_state_1, planet.upgrade_state_2,
            planet.hat_level, artifact_type
        );
        eff_range
    }

    /// Get planet effective speed
    #[external("public")]
    #[view]
    fn get_planet_speed(planet_id: Field) -> pub u64 {
        let planet = self.storage.planets.at(planet_id).read();

        let artifact_id = self.storage.planet_artifact.at(planet_id).read();
        let mut artifact_type = 0;
        if artifact_id != 0 {
             let art = self.storage.artifacts.at(artifact_id).read();
             artifact_type = art.artifact_type;
        }

        let (_, eff_speed, _, _, _, _, _) = crate::planet::state::get_effective_stats(
            planet.range, planet.speed, planet.defense,
            planet.population_cap, planet.population_growth,
            planet.silver_cap, planet.silver_growth,
            planet.upgrade_state_0, planet.upgrade_state_1, planet.upgrade_state_2,
            planet.hat_level, artifact_type
        );
        eff_speed
    }

    /// Get planet effective defense
    #[external("public")]
    #[view]
    fn get_planet_defense(planet_id: Field) -> pub u64 {
        let planet = self.storage.planets.at(planet_id).read();

        let artifact_id = self.storage.planet_artifact.at(planet_id).read();
        let mut artifact_type = 0;
        if artifact_id != 0 {
             let art = self.storage.artifacts.at(artifact_id).read();
             artifact_type = art.artifact_type;
        }

        let (_, _, eff_defense, _, _, _, _) = crate::planet::state::get_effective_stats(
            planet.range, planet.speed, planet.defense,
            planet.population_cap, planet.population_growth,
            planet.silver_cap, planet.silver_growth,
            planet.upgrade_state_0, planet.upgrade_state_1, planet.upgrade_state_2,
            planet.hat_level, artifact_type
        );
        eff_defense
    }

    /// Get revealed coordinates for a planet
    #[external("public")]
    #[view]
    fn get_revealed_coords(planet_id: Field) -> pub crate::types::planet::RevealedCoords {
        crate::types::planet::RevealedCoords {
            location_id: planet_id,
            x: self.storage.revealed_x.at(planet_id).read(),
            y: self.storage.revealed_y.at(planet_id).read(),
            revealer: self.storage.revealed_revealer.at(planet_id).read(),
        }
    }

    // =========================================================================
    // Artifact Query Functions
    // =========================================================================

    /// Get total artifact count
    #[external("public")]
    #[view]
    fn get_artifact_count() -> pub u64 {
        self.storage.artifact_count.read()
    }

    /// Get artifact by ID
    #[external("public")]
    #[view]
    fn get_artifact(artifact_id: Field) -> pub crate::types::artifact::ArtifactState {
        self.storage.artifacts.at(artifact_id).read()
    }

    /// Get artifact on a planet (returns ID, 0 if none)
    #[external("public")]
    #[view]
    fn get_planet_artifact(planet_id: Field) -> pub Field {
        self.storage.planet_artifact.at(planet_id).read()
    }
}


