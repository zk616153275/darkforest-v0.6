// Player type definitions
use dep::aztec::protocol_types::address::AztecAddress;

/// Player public state
/// Corresponds to eth/contracts/DFTypes.sol#Player
pub struct PlayerPublicState {
    // Identity
    pub address: AztecAddress,
    pub is_initialized: bool,

    // Home planet
    pub home_planet_id: Field,
    pub init_timestamp: u64,

    // Score and progression
    pub score: u64,
    pub final_rank: u64,
    pub claimed_reward: bool,

    // Space junk (movement cost)
    pub space_junk: u64,
    pub space_junk_limit: u64,

    // Cooldowns
    pub last_reveal_timestamp: u64,

    // Ships
    pub claimed_ships: bool,
}

impl PlayerPublicState {
    /// Create a default uninitialized player
    pub fn default() -> Self {
        Self {
            address: AztecAddress::zero(),
            is_initialized: false,
            home_planet_id: 0,
            init_timestamp: 0,
            score: 0,
            final_rank: 0,
            claimed_reward: false,
            space_junk: 0,
            space_junk_limit: 0,
            last_reveal_timestamp: 0,
            claimed_ships: false,
        }
    }

    /// Create a new initialized player
    pub fn new(
        address: AztecAddress,
        home_planet_id: Field,
        timestamp: u64,
        space_junk_limit: u64,
    ) -> Self {
        Self {
            address,
            is_initialized: true,
            home_planet_id,
            init_timestamp: timestamp,
            score: 0,
            final_rank: 0,
            claimed_reward: false,
            space_junk: 0,
            space_junk_limit,
            last_reveal_timestamp: 0,
            claimed_ships: false,
        }
    }
}
