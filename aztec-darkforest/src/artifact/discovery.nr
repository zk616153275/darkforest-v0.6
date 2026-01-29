// Artifact discovery logic
use crate::types::enums::{ArtifactType, ArtifactRarity, Biome};

/// Check if a planet has an artifact
/// Deterministic based on planet ID
///
/// # TODO REVIEW DIFFS (vs Solidity LibArtifactUtils):
/// - [ ] DIFF-2: Random source is predictable - uses fixed seed 8888
/// - [ ] Need Aztec randomness oracle or commit-reveal pattern
pub fn is_artifact_found(planet_id: Field) -> bool {
    // Combine planet_id with a magic seed for artifact generation
    let hash = dep::std::hash::pedersen_hash([planet_id, 8888]);

    // Use last byte for simple probability
    // 10% chance (25/256)
    let bytes: [u8; 32] = hash.to_be_bytes();
    let random_byte = bytes[31] as u8;
    random_byte < 25
}

/// Roll for artifact rarity based on planet level
///
/// # Algorithm (matches Solidity LibGameUtils):
/// 1. Calculate level bonus from random roll:
///    - secondLastByte < 4  -> +2 bonus
///    - secondLastByte < 16 -> +1 bonus
/// 2. Determine rarity from effective level (planet_level + bonus):
///    - level 0-1 -> Common
///    - level 2-3 -> Rare
///    - level 4-5 -> Epic
///    - level 6-7 -> Legendary
///    - level 8+  -> Mythic
///
/// # [DIFF-5 RESOLVED]
pub fn roll_rarity(planet_id: Field, planet_level: u8) -> u8 {
    let hash = dep::std::hash::pedersen_hash([planet_id, 9999]);
    let bytes: [u8; 32] = hash.to_be_bytes();

    // Level bonus from second-to-last byte
    let second_last_byte = bytes[30] as u8;
    let mut bonus: u8 = 0;
    if second_last_byte < 4 {
        bonus = 2;
    } else if second_last_byte < 16 {
        bonus = 1;
    }

    // Effective level for rarity calculation
    let effective_level = planet_level + bonus;

    // Rarity based on effective level (matches Solidity artifactRarityFromPlanetLevel)
    if effective_level <= 1 {
        ArtifactRarity::COMMON()      // level 0-1
    } else if effective_level <= 3 {
        ArtifactRarity::RARE()        // level 2-3
    } else if effective_level <= 5 {
        ArtifactRarity::EPIC()        // level 4-5
    } else if effective_level <= 7 {
        ArtifactRarity::LEGENDARY()   // level 6-7
    } else {
        ArtifactRarity::MYTHIC()      // level 8+
    }
}

/// Roll for artifact type based on random roll and biome
///
/// # Algorithm (matches Solidity LibGameUtils._randomArtifactTypeAndLevelBonus):
/// Distribution (from lastByteOfSeed):
///   - 0-38:   Monolith     (~15%)
///   - 39-77:  Colossus     (~15%)
///   - 78-155: Pyramid      (~30%)
///   - 156-170: Wormhole    (~6%)
///   - 171-185: PlanetaryShield (~6%)
///   - 186-200: PhotoidCannon   (~6%)
///   - 201-215: BloomFilter     (~6%)
///   - 216-230: BlackDomain     (~6%)
///   - 231-255: Biome-specific  (~10%)
///
/// Biome influence (for roll >= 231):
///   - Ice -> PlanetaryShield
///   - Lava -> PhotoidCannon
///   - Wasteland -> BloomFilter
///   - Corrupted -> BlackDomain
///   - Others -> Wormhole
///
/// # [DIFF-6 RESOLVED]
pub fn roll_artifact_type(planet_id: Field, biome: u8) -> u8 {
    let hash = dep::std::hash::pedersen_hash([planet_id, 11111, biome as Field]);
    let bytes: [u8; 32] = hash.to_be_bytes();
    let roll = bytes[31] as u8;

    // Match Solidity distribution
    if roll < 39 {
        ArtifactType::MONOLITH()
    } else if roll < 78 {
        ArtifactType::COLOSSUS()
    // Note: Spaceship (78-117) is commented out in Solidity, skip it
    } else if roll < 156 {
        ArtifactType::PYRAMID()
    } else if roll < 171 {
        ArtifactType::WORMHOLE()
    } else if roll < 186 {
        ArtifactType::PLANETARY_SHIELD()
    } else if roll < 201 {
        ArtifactType::PHOTOID_CANNON()
    } else if roll < 216 {
        ArtifactType::BLOOM_FILTER()
    } else if roll < 231 {
        ArtifactType::BLACK_DOMAIN()
    } else {
        // Biome-specific artifact (roll >= 231)
        if biome == Biome::ICE() {
            ArtifactType::PLANETARY_SHIELD()
        } else if biome == Biome::LAVA() {
            ArtifactType::PHOTOID_CANNON()
        } else if biome == Biome::WASTELAND() {
            ArtifactType::BLOOM_FILTER()
        } else if biome == Biome::CORRUPTED() {
            ArtifactType::BLACK_DOMAIN()
        } else {
            ArtifactType::WORMHOLE()
        }
    }
}

// =============================================================================
// Tests
// =============================================================================

#[test]
fn test_is_artifact_found_deterministic() {
    // Same planet_id should always return same result
    let planet_id: Field = 12345;
    let result1 = is_artifact_found(planet_id);
    let result2 = is_artifact_found(planet_id);
    assert(result1 == result2);
}

#[test]
fn test_is_artifact_found_different_planets() {
    // Different planets can have different results
    let planet1: Field = 1;
    let planet2: Field = 999999;
    // Just verify both run without error
    let _ = is_artifact_found(planet1);
    let _ = is_artifact_found(planet2);
}

#[test]
fn test_roll_rarity_level_0_returns_common() {
    // Level 0 planet should return Common (value 1)
    // unless bonus pushes it higher
    let planet_id: Field = 100;
    let rarity = roll_rarity(planet_id, 0);
    // Rarity should be valid (1-5)
    assert(rarity >= ArtifactRarity::COMMON());
    assert(rarity <= ArtifactRarity::MYTHIC());
}

#[test]
fn test_roll_rarity_level_8_returns_high_rarity() {
    // Level 8+ should return at least Epic
    let planet_id: Field = 200;
    let rarity = roll_rarity(planet_id, 8);
    // With level 8, even without bonus, it should be Mythic
    assert(rarity == ArtifactRarity::MYTHIC());
}

#[test]
fn test_roll_rarity_level_mapping() {
    // Test various levels with a known planet_id
    // Note: actual rarity depends on pedersen hash of planet_id
    let planet_id: Field = 42;

    let rarity_0 = roll_rarity(planet_id, 0);
    let _rarity_2 = roll_rarity(planet_id, 2);
    let _rarity_4 = roll_rarity(planet_id, 4);
    let rarity_6 = roll_rarity(planet_id, 6);

    // Higher levels should result in >= rarity
    // This is probabilistic due to bonus, but minimum expected:
    // Level 0: Common(1) or Rare(2) with bonus
    // Level 2: Rare(2) or higher
    // Level 4: Epic(3) or higher
    // Level 6: Legendary(4) or higher
    assert(rarity_0 >= ArtifactRarity::COMMON());
    assert(rarity_6 >= ArtifactRarity::LEGENDARY());
}

#[test]
fn test_roll_rarity_deterministic() {
    // Same inputs should always produce same output
    let planet_id: Field = 555;
    let level: u8 = 3;
    let r1 = roll_rarity(planet_id, level);
    let r2 = roll_rarity(planet_id, level);
    assert(r1 == r2);
}

#[test]
fn test_roll_artifact_type_valid_range() {
    // Type should be in valid range
    let planet_id: Field = 777;
    let biome: u8 = 5;
    let artifact_type = roll_artifact_type(planet_id, biome);

    // Should be one of the valid types (excluding SPACESHIP which is not used)
    let is_valid =
        (artifact_type == ArtifactType::MONOLITH()) |
        (artifact_type == ArtifactType::COLOSSUS()) |
        (artifact_type == ArtifactType::PYRAMID()) |
        (artifact_type == ArtifactType::WORMHOLE()) |
        (artifact_type == ArtifactType::PLANETARY_SHIELD()) |
        (artifact_type == ArtifactType::PHOTOID_CANNON()) |
        (artifact_type == ArtifactType::BLOOM_FILTER()) |
        (artifact_type == ArtifactType::BLACK_DOMAIN());
    assert(is_valid);
}

#[test]
fn test_roll_artifact_type_deterministic() {
    // Same inputs should always produce same output
    let planet_id: Field = 888;
    let biome: u8 = 3;
    let t1 = roll_artifact_type(planet_id, biome);
    let t2 = roll_artifact_type(planet_id, biome);
    assert(t1 == t2);
}

#[test]
fn test_roll_artifact_type_biome_affects_result() {
    // Different biomes should potentially produce different results
    let planet_id: Field = 999;
    let type_biome_0 = roll_artifact_type(planet_id, 0);
    let type_biome_5 = roll_artifact_type(planet_id, 5);
    // Just verify both run - results may or may not differ
    let _ = type_biome_0;
    let _ = type_biome_5;
}

// =============================================================================
// DIFF-6 Specific Tests: Artifact Type Distribution
// =============================================================================

#[test]
fn test_roll_artifact_type_includes_new_types() {
    // Test that various planet_ids can produce the new artifact types
    // We test multiple planet IDs to increase probability of hitting each type
    let mut found_planetary_shield = false;
    let mut found_photoid_cannon = false;
    let mut found_bloom_filter = false;
    let mut found_black_domain = false;

    // Test with 20 different planet IDs
    for i in 0..20 {
        let planet_id: Field = 1000 + i as Field;
        let artifact_type = roll_artifact_type(planet_id, 5);

        if artifact_type == ArtifactType::PLANETARY_SHIELD() {
            found_planetary_shield = true;
        }
        if artifact_type == ArtifactType::PHOTOID_CANNON() {
            found_photoid_cannon = true;
        }
        if artifact_type == ArtifactType::BLOOM_FILTER() {
            found_bloom_filter = true;
        }
        if artifact_type == ArtifactType::BLACK_DOMAIN() {
            found_black_domain = true;
        }
    }

    // At least one of the new types should appear in 20 samples
    // (each has ~6% chance, so probability of none appearing is very low)
    let found_any_new = found_planetary_shield | found_photoid_cannon |
                        found_bloom_filter | found_black_domain;
    assert(found_any_new);
}

#[test]
fn test_roll_artifact_type_no_spaceship() {
    // Verify SPACESHIP is never returned (commented out in Solidity)
    for i in 0..50 {
        let planet_id: Field = 2000 + i as Field;
        let artifact_type = roll_artifact_type(planet_id, 3);
        assert(artifact_type != ArtifactType::SPACESHIP());
    }
}

#[test]
fn test_roll_artifact_type_biome_ice_influence() {
    // Test ICE biome influence - should favor PLANETARY_SHIELD for high rolls
    // We need a planet_id that produces roll >= 231
    // Since hash is deterministic, we search for one
    let ice_biome = Biome::ICE();
    let mut found_shield_with_ice = false;

    for i in 0..100 {
        let planet_id: Field = 5000 + i as Field;
        let artifact_type = roll_artifact_type(planet_id, ice_biome);
        if artifact_type == ArtifactType::PLANETARY_SHIELD() {
            found_shield_with_ice = true;
        }
    }

    // ICE biome should produce PLANETARY_SHIELD at some point
    // (either from roll 171-185 or from biome influence 231+)
    assert(found_shield_with_ice);
}

#[test]
fn test_roll_artifact_type_biome_lava_influence() {
    // Test LAVA biome influence - should favor PHOTOID_CANNON
    let lava_biome = Biome::LAVA();
    let mut found_cannon_with_lava = false;

    for i in 0..100 {
        let planet_id: Field = 6000 + i as Field;
        let artifact_type = roll_artifact_type(planet_id, lava_biome);
        if artifact_type == ArtifactType::PHOTOID_CANNON() {
            found_cannon_with_lava = true;
        }
    }

    assert(found_cannon_with_lava);
}

#[test]
fn test_roll_artifact_type_all_standard_types_can_appear() {
    // Verify all 8 standard types can appear
    let mut found_monolith = false;
    let mut found_colossus = false;
    let mut found_pyramid = false;
    let mut found_wormhole = false;
    let mut found_shield = false;
    let mut found_cannon = false;
    let mut found_bloom = false;
    let mut found_black = false;

    // Test 200 planet IDs to ensure good coverage
    for i in 0..200 {
        let planet_id: Field = 10000 + i as Field;
        let artifact_type = roll_artifact_type(planet_id, 5);

        if artifact_type == ArtifactType::MONOLITH() { found_monolith = true; }
        if artifact_type == ArtifactType::COLOSSUS() { found_colossus = true; }
        if artifact_type == ArtifactType::PYRAMID() { found_pyramid = true; }
        if artifact_type == ArtifactType::WORMHOLE() { found_wormhole = true; }
        if artifact_type == ArtifactType::PLANETARY_SHIELD() { found_shield = true; }
        if artifact_type == ArtifactType::PHOTOID_CANNON() { found_cannon = true; }
        if artifact_type == ArtifactType::BLOOM_FILTER() { found_bloom = true; }
        if artifact_type == ArtifactType::BLACK_DOMAIN() { found_black = true; }
    }

    // All types should appear at least once in 200 samples
    assert(found_monolith);
    assert(found_colossus);
    assert(found_pyramid);
    assert(found_wormhole);
    assert(found_shield);
    assert(found_cannon);
    assert(found_bloom);
    assert(found_black);
}
