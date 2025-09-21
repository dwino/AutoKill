const std = @import("std");
const rl = @import("raylib");
const Color = rl.Color;
const cs = @import("constants.zig");
const dt = @import("datatypes.zig");

// HELPERS

pub fn insideCircle(center_x: f32, center_y: f32, x: f32, y: f32, radius: f32) bool {
    const dx = center_x - x;
    const dy = center_y - y;
    const distance = std.math.sqrt(dx * dx + dy * dy);
    return distance <= radius;
}

pub fn insideMap(x: i32, y: i32) bool {
    return x >= 0 and x < cs.map_width and y >= 0 and y < cs.map_height;
}

pub fn spriteIndexToX(spriteIndex: u16) u16 {
    return spriteIndex % 64;
}

pub fn spriteIndexToY(spriteIndex: u16) u16 {
    return @divFloor(spriteIndex, 64);
}

pub fn mapIndexToX(index: usize) usize {
    return index % cs.map_width;
}

pub fn mapIndexToY(index: usize) usize {
    return @divFloor(index, cs.map_width);
}
//////////

// GENERATORS
pub fn generateNonOverlappingRooms() [cs.max_rooms]dt.Rectangle {
    var new_rooms: [cs.max_rooms]dt.Rectangle = undefined;

    new_rooms[0] = dt.Rectangle{ .x = rl.getRandomValue(cs.bound_x_left, cs.bound_x_right - cs.max_room_width), .y = rl.getRandomValue(cs.bound_y_up, cs.bound_y_down - cs.max_room_height), .width = rl.getRandomValue(cs.min_room_width, cs.max_room_width), .height = rl.getRandomValue(cs.min_room_height, cs.max_room_height) };

    const actual_rooms: i32 = cs.max_rooms;
    var rooms_index: usize = 1;
    var tries: usize = 0;

    while (rooms_index < actual_rooms) {
        var room_overlaps = false;

        const new_room =
            dt.Rectangle{ .x = rl.getRandomValue(cs.bound_x_left, cs.bound_x_right - cs.max_room_width), .y = rl.getRandomValue(cs.bound_y_up, cs.bound_y_down - cs.max_room_height), .width = rl.getRandomValue(cs.min_room_width, cs.max_room_width), .height = rl.getRandomValue(cs.min_room_height, cs.max_room_height) };

        for (0..rooms_index) |i| {
            const old_room = new_rooms[i];

            if (old_room.x + old_room.width >= new_room.x and
                old_room.x <= new_room.x + new_room.width and
                old_room.y + old_room.height >= new_room.y and
                old_room.y <= new_room.y + new_room.height)
            {
                room_overlaps = true;
            }
        }

        if (!room_overlaps) {
            new_rooms[rooms_index] = new_room;
            rooms_index += 1;
        }

        tries += 1;
        std.debug.print("generateRooms() tries: {}", .{tries});
    }

    return new_rooms;
}

pub fn prepareMapAndConnectRooms(rooms: [cs.max_rooms]dt.Rectangle) [cs.map_width * cs.map_width]dt.TileType {
    var new_map: [cs.map_width * cs.map_width]dt.TileType = undefined;

    for (0..cs.map_width * cs.map_height) |i| {
        if (mapIndexToX(i) == 0 or mapIndexToX(i) == cs.map_width - 1 or mapIndexToY(i) == 0 or mapIndexToY(i) == cs.map_height - 1) {
            new_map[i] = dt.TileType.nothing;
        } else {
            new_map[i] = dt.TileType.wall;
        }
    }

    for (0..rooms.len) |i| {
        const this_room = rooms[i];

        for (@abs(this_room.x)..@abs(this_room.x + this_room.width)) |x| {
            for (@abs(this_room.y)..@abs(this_room.y + this_room.height)) |y| {
                new_map[y * cs.map_width + x] = .floor;
            }
        }

        if (i < rooms.len - 1) {
            const next_room = rooms[i + 1];

            const this_room_middle_x = this_room.x + @divTrunc(this_room.width, 2);
            const this_room_middle_y = this_room.y + @divTrunc(this_room.height, 2);

            const next_room_middle_x = next_room.x + @divTrunc(next_room.width, 2);
            const next_room_middle_y = next_room.y + @divTrunc(next_room.height, 2);

            var start_x = this_room_middle_x;
            var start_y = this_room_middle_y;

            const end_x = next_room_middle_x;
            const end_y = next_room_middle_y;

            while (start_x != end_x) {
                if (start_x < end_x) {
                    start_x += 1;
                } else {
                    start_x -= 1;
                }
                new_map[@abs(this_room_middle_y) * cs.map_width + @abs(start_x)] = .floor;
            }
            while (start_y != end_y) {
                if (start_y < end_y) {
                    start_y += 1;
                } else {
                    start_y -= 1;
                }
                new_map[@abs(start_y) * cs.map_width + @abs(next_room_middle_x)] = .floor;
            }
        }
    }

    return new_map;
}

pub fn populateMap(rooms: [cs.max_rooms]dt.Rectangle, allocator: std.mem.Allocator) anyerror![]dt.Entity {
    var new_creatures: std.ArrayListUnmanaged(dt.Entity) = .empty;

    for (0..5) |i| {
        try new_creatures.append(allocator, dt.Entity{ .x = rooms[1].x * cs.tile_width + @as(i32, @intCast(i)) * cs.tile_width, .y = rooms[1].y * cs.tile_height + @as(i32, @intCast(i)) * cs.tile_height, .fov = 0.0 });
    }

    return new_creatures.toOwnedSlice(allocator);
}
//////////
