// Module declarations
mod types;
mod notes;
mod utils;
mod planet;
mod player;
mod artifact; // TODO: Implement artifact module

use aztec::macros::aztec;

#[aztec]
pub contract DarkForest {
    use aztec::{
        protocol_types::address::AztecAddress,
        macros::{functions::{external, initializer, internal, view, only_self}, storage::storage},
        state_vars::{public_mutable::PublicMutable, Map},
    };

    // Import utility functions
    use crate::utils::hash::compute_planet_hash;
    use crate::utils::perlin::compute_perlin;

    // =========================================================================
    // Storage Structure
    // =========================================================================
    #[storage]
    struct Storage<Context> {
        // Admin
        admin: PublicMutable<AztecAddress, Context>,
        paused: PublicMutable<bool, Context>,

        // Game Configuration
        world_radius: PublicMutable<u64, Context>,
        planethash_key: PublicMutable<Field, Context>,
        spacetype_key: PublicMutable<Field, Context>,
        perlin_length_scale: PublicMutable<u64, Context>,

        // Initialization bounds (perlin range for spawning)
        init_perlin_min: PublicMutable<u64, Context>,
        init_perlin_max: PublicMutable<u64, Context>,

        // Perlin thresholds for space types
        perlin_threshold_1: PublicMutable<u64, Context>,
        perlin_threshold_2: PublicMutable<u64, Context>,
        perlin_threshold_3: PublicMutable<u64, Context>,

        // Counters
        planet_count: PublicMutable<u64, Context>,
        player_count: PublicMutable<u64, Context>,

        // Player tracking: address => home_planet_id (0 = not initialized)
        player_home_planets: Map<AztecAddress, PublicMutable<Field, Context>, Context>,

        // Planet tracking: planet_id => owner (zero address = not initialized)
        planet_owners: Map<Field, PublicMutable<AztecAddress, Context>, Context>,

        // Planet perlin values (for determining space type)
        planet_perlin: Map<Field, PublicMutable<u64, Context>, Context>,

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
        self.storage.world_radius.write(world_radius);
        self.storage.planethash_key.write(planethash_key);
        self.storage.spacetype_key.write(spacetype_key);
        self.storage.perlin_length_scale.write(perlin_length_scale);

        // Perlin spawn bounds
        self.storage.init_perlin_min.write(init_perlin_min);
        self.storage.init_perlin_max.write(init_perlin_max);

        // Default perlin thresholds for space types
        self.storage.perlin_threshold_1.write(11);
        self.storage.perlin_threshold_2.write(13);
        self.storage.perlin_threshold_3.write(15);

        // Counters
        self.storage.planet_count.write(0);
        self.storage.player_count.write(0);
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
        planethash_key: Field,
        spacetype_key: Field,
        perlin_scale: u64,
        world_radius: u64,
        init_perlin_min: u64,
        init_perlin_max: u64,
    ) -> pub Field {
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

    /// Internal callback to update public state after player initialization
    ///
    /// This function is called by the private `initialize_player` function.
    /// It updates the on-chain visible state.
    ///
    /// Note: The sender parameter is passed from enqueue_self context
    #[external("public")]
    #[only_self]
    fn initialize_player_callback(planet_id: Field, perlin: u64, sender: AztecAddress) {
        // 1. Check game is not paused
        assert(!self.storage.paused.read(), "Game is paused");

        // 2. Check player not already initialized (home_planet != 0)
        let existing_home = self.storage.player_home_planets.at(sender).read();
        assert(existing_home == 0, "Player already initialized");

        // 3. Check planet not already taken (owner != zero address)
        let existing_owner = self.storage.planet_owners.at(planet_id).read();
        assert(existing_owner == AztecAddress::zero(), "Planet already taken");

        // 4. Store player's home planet
        self.storage.player_home_planets.at(sender).write(planet_id);

        // 5. Store planet owner
        self.storage.planet_owners.at(planet_id).write(sender);

        // 6. Store planet perlin (for space type calculation)
        self.storage.planet_perlin.at(planet_id).write(perlin);

        // 7. Increment counters
        let player_count = self.storage.player_count.read();
        self.storage.player_count.write(player_count + 1);

        let planet_count = self.storage.planet_count.read();
        self.storage.planet_count.write(planet_count + 1);
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
        planethash_key: Field,
    ) {
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

        // 4. Enqueue public callback to process the move
        self.enqueue_self.move_callback(
            from_planet_id,
            to_planet_id,
            energy_sent,
            silver_sent,
            distance,
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
        sender: AztecAddress,
    ) {
        // 1. Check game is not paused
        assert(!self.storage.paused.read(), "Game is paused");

        // 2. Verify sender owns the source planet
        let from_owner = self.storage.planet_owners.at(from_planet_id).read();
        assert(from_owner == sender, "Not planet owner");

        // 3. Verify source planet is initialized
        assert(from_owner != AztecAddress::zero(), "Source planet not initialized");

        // 4. Initialize destination planet if needed (as unowned planet)
        let to_owner = self.storage.planet_owners.at(to_planet_id).read();
        if to_owner == AztecAddress::zero() {
            // Planet not initialized yet - increment planet count
            // Note: Will be owned by arrival processing
            let planet_count = self.storage.planet_count.read();
            self.storage.planet_count.write(planet_count + 1);
        }

        // 5. Store arrival information for later processing
        // Note: In a full implementation, we would store arrivals in a queue
        // and process them based on travel time. For now, we just validate.

        // Basic validations
        assert(energy_sent > 0, "Must send some energy");
        assert(distance > 0, "Cannot move to same planet");

        // Note: Full arrival processing would include:
        // - Calculate travel time based on distance and speed
        // - Store arrival in pending arrivals queue
        // - Process arrival when travel time elapses

        // For now, just emit that a move was initiated
        // The _distance and _silver_sent are used for future implementation
        let _ = distance;
        let _ = silver_sent;
    }

    // =========================================================================
    // Location Reveal
    // =========================================================================

    /// Reveal a planet's location publicly
    ///
    /// # Arguments
    /// * `x`, `y` - Private coordinates
    /// * `planet_id` - Public planet ID
    /// * `planethash_key` - Key for verification
    #[external("private")]
    fn reveal_location(
        x: Field,
        y: Field,
        planet_id: Field,
        planethash_key: Field
    ) {
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
        self.storage.planet_owners.at(planet_id).read()
    }

    /// Get the perlin value of a planet
    /// Used to determine space type
    #[external("public")]
    #[view]
    fn get_planet_perlin(planet_id: Field) -> pub u64 {
        self.storage.planet_perlin.at(planet_id).read()
    }

    /// Check if a planet is initialized (has an owner)
    #[external("public")]
    #[view]
    fn is_planet_initialized(planet_id: Field) -> pub bool {
        self.storage.planet_owners.at(planet_id).read() != AztecAddress::zero()
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
}
