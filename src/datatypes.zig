pub const Entity = struct { x: i32, y: i32, fov: f32 };

pub const Rectangle = struct { x: i32, y: i32, width: i32, height: i32 };

pub const TileType = enum(u8) { nothing, floor, wall };
