// Arrival data for delayed planet movements
use dep::aztec::protocol_types::address::AztecAddress;
use dep::aztec::protocol_types::traits::{Serialize, Deserialize, Packable, ToField, FromField};

/// Arrival data representing an in-flight voyage
/// Corresponds to eth/contracts/DFTypes.sol#ArrivalData
pub struct ArrivalData {
    pub id: u64,
    pub player: AztecAddress,
    pub from_planet: Field,
    pub to_planet: Field,
    pub pop_arriving: u64,      // Energy after decay
    pub silver_moved: u64,
    pub departure_time: u64,
    pub arrival_time: u64,
    pub distance: u64,
}

impl ArrivalData {
    pub fn default() -> Self {
        Self {
            id: 0,
            player: AztecAddress::zero(),
            from_planet: 0,
            to_planet: 0,
            pop_arriving: 0,
            silver_moved: 0,
            departure_time: 0,
            arrival_time: 0,
            distance: 0,
        }
    }

    pub fn is_empty(self) -> bool {
        self.id == 0
    }
}

impl Serialize for ArrivalData {
    let N: u32 = 9;
    fn serialize(self) -> [Field; 9] {
        [
            self.id as Field,
            self.player.to_field(),
            self.from_planet,
            self.to_planet,
            self.pop_arriving as Field,
            self.silver_moved as Field,
            self.departure_time as Field,
            self.arrival_time as Field,
            self.distance as Field
        ]
    }
}

impl Deserialize for ArrivalData {
    let N: u32 = 9;
    fn deserialize(input: [Field; 9]) -> Self {
        Self {
            id: input[0] as u64,
            player: AztecAddress::from_field(input[1]),
            from_planet: input[2],
            to_planet: input[3],
            pop_arriving: input[4] as u64,
            silver_moved: input[5] as u64,
            departure_time: input[6] as u64,
            arrival_time: input[7] as u64,
            distance: input[8] as u64,
        }
    }
}

impl Packable for ArrivalData {
    let N: u32 = 9;
    fn pack(self) -> [Field; 9] {
        self.serialize()
    }
    fn unpack(input: [Field; 9]) -> Self {
        Self::deserialize(input)
    }
}
