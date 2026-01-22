// Artifact type definitions
use dep::aztec::protocol_types::address::AztecAddress;

/// Artifact state
/// Corresponds to eth/contracts/DFTypes.sol#Artifact
struct ArtifactState {
    // Identity
    id: Field,
    is_initialized: bool,

    // Discovery
    planet_discovered_on: Field,
    discoverer: AztecAddress,
    minted_at_timestamp: u64,

    // Type and rarity
    artifact_type: u8,
    rarity: u8,
    planet_biome: u8,

    // Activation state
    activations: u64,
    last_activated: u64,
    last_deactivated: u64,

    // Special data
    wormhole_to: Field,     // Target planet for wormhole artifacts
    controller: AztecAddress, // For spaceships
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
