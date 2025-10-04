const cs = @import("constants.zig");

pub const Position = struct { x: i32, y: i32 };

pub const Rectangle = struct { x: i32, y: i32, width: i32, height: i32 };

pub const TileType = enum(u8) { nothing, floor, wall };
pub const Creatures = struct {
    max_index: usize,
    id: [cs.max_creatures]usize,
    position: [cs.max_creatures]Position,
    health: [cs.max_creatures]i32,
};
