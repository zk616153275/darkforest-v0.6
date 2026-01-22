// Energy Note - Optional private storage for planet energy
// Allows hiding attack strength from other players

use dep::aztec::protocol_types::traits::Packable;
use dep::aztec::macros::notes::note;

/// Energy Note
/// Stores private energy value for a planet
///
/// This is an optional privacy enhancement - in the original Dark Forest,
/// energy is public. In Aztec, we can make it private to hide attack strength.
#[derive(Packable)]
#[note]
pub struct EnergyNote {
    // The planet this energy belongs to
    planet_id: Field,

    // The energy amount (private) - stored as Field for note compatibility
    energy: Field,

    // Random value for uniqueness
    randomness: Field,
}

impl EnergyNote {
    /// Create a new energy note
    pub fn new(planet_id: Field, energy: Field, randomness: Field) -> Self {
        Self { planet_id, energy, randomness }
    }

    /// Get the planet ID
    pub fn get_planet_id(self) -> Field {
        self.planet_id
    }

    /// Get the energy value
    pub fn get_energy(self) -> Field {
        self.energy
    }

    /// Create a note with updated energy (for consume/create pattern)
    pub fn with_energy(self, new_energy: Field, new_randomness: Field) -> Self {
        Self {
            planet_id: self.planet_id,
            energy: new_energy,
            randomness: new_randomness,
        }
    }
}
