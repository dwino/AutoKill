const std = @import("std");
const rl = @import("raylib");
const Color = rl.Color;
const cs = @import("constants.zig");
const dt = @import("datatypes.zig");
const s = @import("state.zig");

pub fn gameRender() void {
    rl.beginTextureMode(s.fog_of_war);
    rl.clearBackground(.blank);

    // render visible part of map tile by tile

    var start_x = s.player.x - 80;
    var end_x = s.player.x + 80;

    var start_y = s.player.y - 50;
    var end_y = s.player.y + 50;

    if (start_x < 0) {
        start_x = 0;
    }
    if (end_x > cs.map_width) {
        end_x = cs.map_width;
    }
    if (start_y < 0) {
        start_y = 0;
    }
    if (end_y > cs.map_height) {
        end_y = cs.map_height;
    }

    var x = start_x;

    while (x <= end_x) {
        var y = start_y;
        while (y <= end_y) {
            if (!insideCircle(@floatFromInt(s.player.x), @floatFromInt(s.player.y), @floatFromInt(x), @floatFromInt(y), s.player.fov)) {
                if (x > 0 and y > 0 and s.tiles_seen.contains(@abs(y) * cs.map_width + @abs(x))) {
                    rl.drawRectangle(@intCast(x), @intCast(y), 1, 1, rl.fade(.black, 0.5));
                } else {
                    rl.drawRectangle(@intCast(x), @intCast(y), 1, 1, .black);
                }
            }

            y += 1;
        }
        x += 1;
    }

    // const start_x_abs = @abs(start_x);
    // const end_x_abs = @abs(end_x);

    // const start_y_abs = @abs(start_y);
    // const end_y_abs = @abs(end_y);

    // for (start_x_abs..end_x_abs) |x| {
    //     for (start_y_abs..end_y_abs) |y| {
    //         if (!insideCircle(@floatFromInt(player.x), @floatFromInt(player.y), @floatFromInt(x), @floatFromInt(y), player.fov)) {
    //             if (tiles_seen.contains(y * map_width + x)) {
    //                 rl.drawRectangle(@intCast(x), @intCast(y), 1, 1, rl.fade(.black, 0.5));
    //             } else {
    //                 rl.drawRectangle(@intCast(x), @intCast(y), 1, 1, .black);
    //             }
    //         }
    //     }
    // }

    // render entire fov map, slow for large maps
    // for (0..map_width) |x| {
    //     for (0..map_height) |y| {
    //         // const tile = map[x][y];
    //         // if (tile.x < player.x - 4 or tile.y < player.y - 4 or
    //         //     tile.x > player.x + 4 or tile.y > player.y + 4)
    //         if (!insideCircle(@floatFromInt(player.x), @floatFromInt(player.y), @floatFromInt(x), @floatFromInt(y), player.fov)) {
    //             if (tiles_seen.contains(y * map_width + x)) {
    //                 rl.drawRectangle(@intCast(x), @intCast(y), 1, 1, rl.fade(.black, 0.5));
    //             } else {
    //                 rl.drawRectangle(@intCast(x), @intCast(y), 1, 1, .black);
    //             }
    //         }
    //     }
    // }

    rl.endTextureMode();

    rl.beginDrawing();
    rl.clearBackground(Color.black);
    rl.beginMode2D(s.camera);

    // render visible part of map tile by tile
    // var tile: Tile = undefined;
    // var texture_index_x: i32 = 0;
    // var texture_index_y: i32 = 0;

    // const sprite_index_at_player_x = player.x;
    // var start_x = sprite_index_at_player_x - 25;
    // var end_x = sprite_index_at_player_x + 25;

    // const sprite_index_at_player_y = player.y;
    // var start_y = sprite_index_at_player_y - 25;
    // var end_y = sprite_index_at_player_y + 25;

    // if (start_x < 0) {
    //     start_x = 0;
    // }
    // if (end_x > map_width - 1) {
    //     end_x = map_width - 1;
    // }
    // if (start_y < 0) {
    //     start_y = 0;
    // }
    // if (end_y > map_height - 1) {
    //     end_y = map_height - 1;
    // }

    // const start_x_abs = @abs(start_x);
    // const end_x_abs = @abs(end_x);

    // const start_y_abs = @abs(start_y);
    // const end_y_abs = @abs(end_y);

    // for (start_x_abs..end_x_abs) |x| {
    //     for (start_y_abs..end_y_abs) |y| {
    //         // tile = map[i][j];

    //         // texture_index_x = tile.type.x_index;
    //         // texture_index_y = tile.type.y_index;

    //         drawTile(@as(f32, @floatFromInt(x * tile_width)), @as(f32, @floatFromInt(y * tile_height)), tile.sprite_index.x_index, tile.sprite_index.y_index);
    //     }
    // }

    // render entire map  tile by tile (slow for big maps)
    // for (0..world_width) |i| {
    //     for (0..world_width) |j| {
    //         tile = map[i][j];

    //         texture_index_x = tile.type.x_index;
    //         texture_index_y = tile.type.y_index;

    //         drawTile(@as(f32, @floatFromInt(tile.x * tile_width)), @as(f32, @floatFromInt(tile.y * tile_height)), texture_index_x, texture_index_y);
    //     }
    // }

    // render map
    const source_rect_map = rl.Rectangle{ .x = 0.0, .y = 0.0, .width = @as(f32, @floatFromInt(s.map_texture.texture.width)), .height = -@as(f32, @floatFromInt(s.map_texture.texture.height)) };
    const dest_rect_map = rl.Rectangle{ .x = 0.0, .y = 0.0, .width = @as(f32, @floatFromInt(cs.map_width * cs.tile_width)), .height = @as(f32, @floatFromInt(cs.map_height * cs.tile_height)) };
    const origin_map = rl.Vector2{ .x = 0, .y = 0 };
    rl.drawTexturePro(s.map_texture.texture, source_rect_map, dest_rect_map, origin_map, 0.0, .white);

    // render creatures
    for (s.creatures.items) |creature| {
        drawTile(@as(f32, @floatFromInt(creature.x)), @as(f32, @floatFromInt(creature.y)), 8, 94);
    }

    // render player
    drawTile(s.camera.target.x, s.camera.target.y, 36, 84);
    drawTile(s.camera.target.x, s.camera.target.y, 5, 80);
    drawTile(s.camera.target.x, s.camera.target.y, 50, 82);
    drawTile(s.camera.target.x, s.camera.target.y, 34, 90);

    const source_rect_fog = rl.Rectangle{ .x = 0.0, .y = 0.0, .width = @as(f32, @floatFromInt(s.fog_of_war.texture.width)), .height = -@as(f32, @floatFromInt(s.fog_of_war.texture.height)) };

    rl.drawTexturePro(s.fog_of_war.texture, source_rect_fog, dest_rect_map, origin_map, 0.0, .white);

    rl.endMode2D();

    rl.drawRectangle(5, 5, 330, 120, Color.fade(Color.sky_blue, 0.5));
    rl.drawRectangleLines(5, 5, 330, 120, Color.blue);

    rl.drawText(rl.textFormat("Camera Target: %06.2f , %06.2f", .{ s.camera.target.x, s.camera.target.y }), 15, 10, 14, Color.yellow);
    rl.drawText(rl.textFormat("Camera zoom: %06.2f", .{s.camera.zoom}), 15, 30, 14, Color.yellow);
    rl.endDrawing();
}

pub fn gameShutdown() void {
    s.tiles_seen.deinit();
    s.tileTypeSpriteIndex.deinit();
    s.creatures.deinit(cs.allocator);
    rl.unloadTexture(s.tilesheet);
    rl.unloadRenderTexture(s.fog_of_war);
    //rl.unloadSound(d.sounds[0]);
    rl.stopMusicStream(s.music[0]);
    rl.unloadMusicStream(s.music[0]);
    rl.closeAudioDevice();
    rl.closeWindow(); // Close window and OpenGL context
}

pub fn drawTile(x_pos: f32, y_pos: f32, texture_index_x: i32, texture_index_y: i32) void {
    const source_rect = rl.Rectangle{ .x = @as(f32, @floatFromInt(texture_index_x * cs.tile_width)), .y = @as(f32, @floatFromInt(texture_index_y * cs.tile_height)), .width = @as(f32, @floatFromInt(cs.tile_width)), .height = @as(f32, @floatFromInt(cs.tile_height)) };
    const dest_rect = rl.Rectangle{ .x = x_pos, .y = y_pos, .width = @as(f32, @floatFromInt(cs.tile_width)), .height = @as(f32, @floatFromInt(cs.tile_height)) };
    const origin = rl.Vector2{ .x = 0, .y = 0 };
    rl.drawTexturePro(s.tilesheet, source_rect, dest_rect, origin, 0.0, Color.white);
}

pub fn insideCircle(center_x: f32, center_y: f32, x: f32, y: f32, radius: f32) bool {
    const dx = center_x - x;
    const dy = center_y - y;
    const distance = std.math.sqrt(dx * dx + dy * dy);
    return distance <= radius;
}

pub fn insideMap(x: i32, y: i32) bool {
    return x >= 0 and x < cs.map_width and y >= 0 and y < cs.map_height;
}

pub fn spriteIndexToX(tileType: dt.TileType) u16 {
    const spriteIndex = s.tileTypeSpriteIndex.get(tileType);
    return spriteIndex.? % 64;
}

pub fn spriteIndexToY(tileType: dt.TileType) u16 {
    const spriteIndex = s.tileTypeSpriteIndex.get(tileType);
    return @divFloor(spriteIndex.?, 64);
}

pub fn mapIndexToX(index: usize) usize {
    return index % cs.map_width;
}

pub fn mapIndexToY(index: usize) usize {
    return @divFloor(index, cs.map_width);
}

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
