// Artifact type definitions
use dep::aztec::protocol_types::{
    address::AztecAddress,
    traits::{Serialize, Deserialize, Packable, ToField, FromField}
};

/// Artifact state
/// Corresponds to eth/contracts/DFTypes.sol#Artifact
pub struct ArtifactState {
    // Identity
    pub id: Field,
    pub is_initialized: bool,

    // Discovery
    pub planet_discovered_on: Field,
    pub discoverer: AztecAddress,
    pub minted_at_timestamp: u64,

    // Type and rarity
    pub artifact_type: u8,
    pub rarity: u8,
    pub planet_biome: u8,

    // Activation state
    pub activations: u64,
    pub last_activated: u64,
    pub last_deactivated: u64,

    // Special data
    pub wormhole_to: Field,     // Target planet for wormhole artifacts
    pub controller: AztecAddress, // For spaceships
}

impl Serialize for ArtifactState {
    let N: u32 = 13;
    fn serialize(self) -> [Field; 13] {
        [
            self.id,
            self.is_initialized as Field,
            self.planet_discovered_on,
            self.discoverer.to_field(),
            self.minted_at_timestamp as Field,
            self.artifact_type as Field,
            self.rarity as Field,
            self.planet_biome as Field,
            self.activations as Field,
            self.last_activated as Field,
            self.last_deactivated as Field,
            self.wormhole_to,
            self.controller.to_field(),
        ]
    }
}

impl Deserialize for ArtifactState {
    let N: u32 = 13;
    fn deserialize(input: [Field; 13]) -> Self {
        Self {
            id: input[0],
            is_initialized: input[1] != 0,
            planet_discovered_on: input[2],
            discoverer: AztecAddress::from_field(input[3]),
            minted_at_timestamp: input[4] as u64,
            artifact_type: input[5] as u8,
            rarity: input[6] as u8,
            planet_biome: input[7] as u8,
            activations: input[8] as u64,
            last_activated: input[9] as u64,
            last_deactivated: input[10] as u64,
            wormhole_to: input[11],
            controller: AztecAddress::from_field(input[12]),
        }
    }
}

impl Packable for ArtifactState {
    let N: u32 = 13;
    fn pack(self) -> [Field; 13] {
        self.serialize()
    }
    fn unpack(input: [Field; 13]) -> Self {
        Self::deserialize(input)
    }
}

impl ArtifactState {
    pub fn default() -> Self {
        Self {
            id: 0,
            is_initialized: false,
            planet_discovered_on: 0,
            discoverer: AztecAddress::zero(),
            minted_at_timestamp: 0,
            artifact_type: 0,
            rarity: 0,
            planet_biome: 0,
            activations: 0,
            last_activated: 0,
            last_deactivated: 0,
            wormhole_to: 0,
            controller: AztecAddress::zero(),
        }
    }

    /// Check if artifact is currently activated
    pub fn is_activated(self) -> bool {
        self.last_activated > self.last_deactivated
    }
}
