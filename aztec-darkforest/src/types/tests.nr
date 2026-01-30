// Types module tests - PlanetPublicState packing/unpacking
use crate::types::planet::PlanetPublicState;
use dep::aztec::protocol_types::traits::{Serialize, Deserialize, FromField};
use dep::aztec::protocol_types::address::AztecAddress;

// =========================================================================
// Combined Field 1 (Metadata): level, planet_type, space_type
// =========================================================================

#[test]
fn test_metadata_pack_unpack() {
    let mut planet = PlanetPublicState::default();
    planet.level = 5;
    planet.planet_type = 3;
    planet.space_type = 2;

    let serialized = planet.serialize();
    let deserialized = PlanetPublicState::deserialize(serialized);

    assert(deserialized.level == 5);
    assert(deserialized.planet_type == 3);
    assert(deserialized.space_type == 2);
}

#[test]
fn test_metadata_boundary_values() {
    let mut planet = PlanetPublicState::default();
    planet.level = 0;           // Min
    planet.planet_type = 255;   // Max u8
    planet.space_type = 128;    // Mid value

    let serialized = planet.serialize();
    let deserialized = PlanetPublicState::deserialize(serialized);

    assert(deserialized.level == 0);
    assert(deserialized.planet_type == 255);
    assert(deserialized.space_type == 128);
}

// =========================================================================
// Combined Field 2 (Upgrades): upgrade_state_0/1/2, hat_level
// =========================================================================

#[test]
fn test_upgrades_pack_unpack() {
    let mut planet = PlanetPublicState::default();
    planet.upgrade_state_0 = 4;
    planet.upgrade_state_1 = 3;
    planet.upgrade_state_2 = 2;
    planet.hat_level = 7;

    let serialized = planet.serialize();
    let deserialized = PlanetPublicState::deserialize(serialized);

    assert(deserialized.upgrade_state_0 == 4);
    assert(deserialized.upgrade_state_1 == 3);
    assert(deserialized.upgrade_state_2 == 2);
    assert(deserialized.hat_level == 7);
}

#[test]
fn test_upgrades_max_values() {
    let mut planet = PlanetPublicState::default();
    planet.upgrade_state_0 = 255;
    planet.upgrade_state_1 = 255;
    planet.upgrade_state_2 = 255;
    planet.hat_level = 255;

    let serialized = planet.serialize();
    let deserialized = PlanetPublicState::deserialize(serialized);

    assert(deserialized.upgrade_state_0 == 255);
    assert(deserialized.upgrade_state_1 == 255);
    assert(deserialized.upgrade_state_2 == 255);
    assert(deserialized.hat_level == 255);
}

// =========================================================================
// Combined Field 3 (Flags): is_initialized, is_home_planet, is_destroyed, has_tried_finding_artifact
// =========================================================================

#[test]
fn test_flags_pack_unpack_all_false() {
    let mut planet = PlanetPublicState::default();
    planet.is_initialized = false;
    planet.is_home_planet = false;
    planet.is_destroyed = false;
    planet.has_tried_finding_artifact = false;

    let serialized = planet.serialize();
    let deserialized = PlanetPublicState::deserialize(serialized);

    assert(deserialized.is_initialized == false);
    assert(deserialized.is_home_planet == false);
    assert(deserialized.is_destroyed == false);
    assert(deserialized.has_tried_finding_artifact == false);
}

#[test]
fn test_flags_pack_unpack_all_true() {
    let mut planet = PlanetPublicState::default();
    planet.is_initialized = true;
    planet.is_home_planet = true;
    planet.is_destroyed = true;
    planet.has_tried_finding_artifact = true;

    let serialized = planet.serialize();
    let deserialized = PlanetPublicState::deserialize(serialized);

    assert(deserialized.is_initialized == true);
    assert(deserialized.is_home_planet == true);
    assert(deserialized.is_destroyed == true);
    assert(deserialized.has_tried_finding_artifact == true);
}

#[test]
fn test_flags_pack_unpack_mixed() {
    let mut planet = PlanetPublicState::default();
    planet.is_initialized = true;
    planet.is_home_planet = false;
    planet.is_destroyed = true;
    planet.has_tried_finding_artifact = false;

    let serialized = planet.serialize();
    let deserialized = PlanetPublicState::deserialize(serialized);

    assert(deserialized.is_initialized == true);
    assert(deserialized.is_home_planet == false);
    assert(deserialized.is_destroyed == true);
    assert(deserialized.has_tried_finding_artifact == false);
}

// =========================================================================
// Full Roundtrip Test
// =========================================================================

#[test]
fn test_full_planet_roundtrip() {
    let owner = AztecAddress::from_field(999);
    let invader = AztecAddress::from_field(888);
    let capturer = AztecAddress::from_field(777);

    let planet = PlanetPublicState {
        planet_id: 12345,
        owner,
        level: 7,
        planet_type: 2,
        space_type: 1,
        range: 1000,
        speed: 75,
        defense: 80,
        population: 5000,
        population_cap: 10000,
        population_growth: 100,
        silver_cap: 5000,
        silver_growth: 50,
        silver: 2500,
        is_initialized: true,
        is_home_planet: true,
        is_destroyed: false,
        last_updated: 1234567890,
        upgrade_state_0: 3,
        upgrade_state_1: 2,
        upgrade_state_2: 1,
        hat_level: 5,
        has_tried_finding_artifact: true,
        prospected_block_number: 1000,
        invader,
        invade_start_block: 500,
        capturer,
        perlin: 25,
    };

    let serialized = planet.serialize();
    let deserialized = PlanetPublicState::deserialize(serialized);

    // Verify all fields survived roundtrip
    assert(deserialized.planet_id == 12345);
    assert(deserialized.owner == owner);
    assert(deserialized.level == 7);
    assert(deserialized.planet_type == 2);
    assert(deserialized.space_type == 1);
    assert(deserialized.range == 1000);
    assert(deserialized.speed == 75);
    assert(deserialized.defense == 80);
    assert(deserialized.population == 5000);
    assert(deserialized.population_cap == 10000);
    assert(deserialized.population_growth == 100);
    assert(deserialized.silver_cap == 5000);
    assert(deserialized.silver_growth == 50);
    assert(deserialized.silver == 2500);
    assert(deserialized.is_initialized == true);
    assert(deserialized.is_home_planet == true);
    assert(deserialized.is_destroyed == false);
    assert(deserialized.last_updated == 1234567890);
    assert(deserialized.upgrade_state_0 == 3);
    assert(deserialized.upgrade_state_1 == 2);
    assert(deserialized.upgrade_state_2 == 1);
    assert(deserialized.hat_level == 5);
    assert(deserialized.has_tried_finding_artifact == true);
    assert(deserialized.prospected_block_number == 1000);
    assert(deserialized.invader == invader);
    assert(deserialized.invade_start_block == 500);
    assert(deserialized.capturer == capturer);
    assert(deserialized.perlin == 25);
}
