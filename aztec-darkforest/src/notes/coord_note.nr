// Coordinate Note - Private storage for planet coordinates
// Only the note owner knows the actual x, y coordinates

use dep::aztec::protocol_types::traits::Packable;
use dep::aztec::macros::notes::note;

/// Coordinate Note
/// Stores the private coordinates of a planet that only the owner knows
///
/// This is the core privacy primitive - the planet_id (hash) is public,
/// but the actual x, y coordinates are private and stored in this note.
#[derive(Packable)]
#[note]
pub struct CoordNote {
    // The public planet ID (hash of coordinates)
    planet_id: Field,

    // Private coordinates (only visible to note owner)
    x: Field,
    y: Field,

    // Perlin value at this coordinate
    perlin: Field,

    // Random value to prevent note collision
    randomness: Field,
}

impl CoordNote {
    /// Create a new coordinate note
    pub fn new(
        planet_id: Field,
        x: Field,
        y: Field,
        perlin: Field,
        randomness: Field,
    ) -> Self {
        Self { planet_id, x, y, perlin, randomness }
    }

    /// Get the planet ID
    pub fn get_planet_id(self) -> Field {
        self.planet_id
    }

    /// Get the x coordinate (private)
    pub fn get_x(self) -> Field {
        self.x
    }

    /// Get the y coordinate (private)
    pub fn get_y(self) -> Field {
        self.y
    }

    /// Get the perlin value
    pub fn get_perlin(self) -> Field {
        self.perlin
    }
}
