const std = @import("std");

const SEGMENT_BITS: u8 = 0x7F;
const CONTINUE_BIT: u8 = 0x80;

const VarIntError = error{TooLongVarInt};

pub fn readVarInt(ptr: []const u8) !i32 {
    var value: u64 = 0;
    var index: u6 = 0;

    for (ptr) |byte| {
        value |= @as(u64, @truncate(u7, byte)) << index;

        if ((byte & CONTINUE_BIT) == 0) {
            break;
        }

        index += 7;

        if (index >= 32) {
            return VarIntError.TooLongVarInt;
        }
    }

    return @truncate(i32, @bitCast(i64, value));
}

pub fn readVarLong(ptr: []const u8) !i64 {
    var value: u128 = 0;
    var index: u7 = 0;
    for (ptr) |byte| {
        value |= @as(u128, @truncate(u7, byte)) << index;

        if ((byte & CONTINUE_BIT) == 0) {
            break;
        }

        index += 7;

        if (index >= 64) {
            return VarIntError.TooLongVarInt;
        }
    }

    return @truncate(i64, @bitCast(i128, value));
}
