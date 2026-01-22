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
}
