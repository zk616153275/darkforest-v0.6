/// Check if byte at specific index of field is less than 16 (0x10)
/// Matches LibGameUtils.sol logic: uint256(uint8(_b[i])) < 16
pub fn is_byte_less_than_16(field: Field, byte_index: u32) -> bool {
    let bytes = field.to_be_bytes::<32>();
    // In Solidity keys are byte 9, 10, 11, etc. from packed encoding.
    // Here we use the field bytes directly. Use big-endian to match "packed" intuition?
    // LibGameUtils used `abi.encodePacked(_location)` which is big-endian for uint256.
    bytes[byte_index] < 16
}

pub fn is_pop_cap_boost(location: Field) -> bool {
    // Solidity: byte 9
    is_byte_less_than_16(location, 9)
}

pub fn is_pop_gro_boost(location: Field) -> bool {
    // Solidity: byte 10
    is_byte_less_than_16(location, 10)
}

pub fn is_range_boost(location: Field) -> bool {
    // Solidity: byte 11
    is_byte_less_than_16(location, 11)
}

pub fn is_speed_boost(location: Field) -> bool {
    // Solidity: byte 12
    is_byte_less_than_16(location, 12)
}

pub fn is_def_boost(location: Field) -> bool {
    // Solidity: byte 13
    is_byte_less_than_16(location, 13)
}

pub fn is_half_space_junk(location: Field) -> bool {
    // Solidity: byte 14
    is_byte_less_than_16(location, 14)
}
