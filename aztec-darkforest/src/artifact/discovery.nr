// Artifact discovery logic
use crate::types::enums::{ArtifactType, ArtifactRarity};

/// Check if a planet has an artifact
/// Deterministic based on planet ID
pub fn is_artifact_found(planet_id: Field) -> bool {
    // Combine planet_id with a magic seed for artifact generation
    let hash = dep::std::hash::pedersen_hash([planet_id, 8888]);

    // Use last byte for simple probability
    // 10% chance (25/256)
    let bytes: [u8; 32] = hash.to_be_bytes();
    let random_byte = bytes[31] as u8;
    random_byte < 25
}

/// Roll for artifact rarity
pub fn roll_rarity(planet_id: Field) -> u8 {
    let hash = dep::std::hash::pedersen_hash([planet_id, 9999]);
    let bytes: [u8; 32] = hash.to_be_bytes();
    let roll = bytes[31] as u8;

    if roll < 150 {
        ArtifactRarity::COMMON() // ~60%
    } else if roll < 220 {
        ArtifactRarity::RARE() // ~25%
    } else if roll < 245 {
        ArtifactRarity::EPIC() // ~10%
    } else if roll < 253 {
        ArtifactRarity::LEGENDARY() // ~3%
    } else {
        ArtifactRarity::MYTHIC() // ~1%
    }
}

/// Roll for artifact type
pub fn roll_artifact_type(planet_id: Field, biome: u8) -> u8 {
    let hash = dep::std::hash::pedersen_hash([planet_id, 11111, biome as Field]);
    let bytes: [u8; 32] = hash.to_be_bytes();
    let roll = bytes[31] as u8;

    // Simple distribution for now
    if roll < 50 {
         ArtifactType::MONOLITH()
    } else if roll < 100 {
         ArtifactType::COLOSSUS()
    } else if roll < 150 {
         ArtifactType::SPACESHIP()
    } else if roll < 200 {
         ArtifactType::PYRAMID()
    } else {
         ArtifactType::WORMHOLE()
    }
}
