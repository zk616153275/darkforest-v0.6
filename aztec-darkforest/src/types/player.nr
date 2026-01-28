// Player type definitions
use dep::aztec::protocol_types::address::AztecAddress;
use dep::aztec::protocol_types::traits::{Serialize, Deserialize, Packable, ToField, FromField};

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

impl Serialize for PlayerPublicState {
    let N: u32 = 11;
    fn serialize(self) -> [Field; 11] {
        [
            self.address.to_field(),
            self.is_initialized as Field,
            self.home_planet_id,
            self.init_timestamp as Field,
            self.score as Field,
            self.final_rank as Field,
            self.claimed_reward as Field,
            self.space_junk as Field,
            self.space_junk_limit as Field,
            self.last_reveal_timestamp as Field,
            self.claimed_ships as Field,
        ]
    }
}

impl Deserialize for PlayerPublicState {
    let N: u32 = 11;
    fn deserialize(input: [Field; 11]) -> Self {
        Self {
            address: AztecAddress::from_field(input[0]),
            is_initialized: input[1] != 0,
            home_planet_id: input[2],
            init_timestamp: input[3] as u64,
            score: input[4] as u64,
            final_rank: input[5] as u64,
            claimed_reward: input[6] != 0,
            space_junk: input[7] as u64,
            space_junk_limit: input[8] as u64,
            last_reveal_timestamp: input[9] as u64,
            claimed_ships: input[10] != 0,
        }
    }
}

impl Packable for PlayerPublicState {
    let N: u32 = 11;
    fn pack(self) -> [Field; 11] {
        self.serialize()
    }
    fn unpack(input: [Field; 11]) -> Self {
        Self::deserialize(input)
    }
}
