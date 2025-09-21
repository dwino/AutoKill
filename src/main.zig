const std = @import("std");
const rl = @import("raylib");
const Color = rl.Color;
const data = @import("data.zig");

pub fn main() anyerror!void {
    try gameStartup();
    defer gameShutdown();

    while (!rl.windowShouldClose()) {
        try gameUpdate();
        gameRender();

        std.debug.print("frametime: {}\n", .{rl.getFrameTime() * 1000});
    }
}

pub fn gameStartup() anyerror!void {
    rl.initWindow(
        data.screen_width,
        data.screen_height,
        "AutoKill",
    );
    rl.initAudioDevice();

    const image: rl.Image = try rl.loadImage("tilesheet.png");
    data.tilesheet = try rl.loadTextureFromImage(image);
    rl.unloadImage(image);

    data.sounds[0] = try rl.loadSound("Audio/footstep00.ogg");
    data.music[0] = try rl.loadMusicStream("Music/metal1.mp3");

    data.map_texture = try rl.loadRenderTexture(data.map_width * data.tile_width, data.map_height * data.tile_height);

    data.fog_of_war = try rl.loadRenderTexture(data.map_width, data.map_height);
    rl.setTextureFilter(data.fog_of_war.texture, .bilinear);

    rl.setTargetFPS(60);

    try data.tileTypeSpriteIndex.put(.nothing, 18);
    try data.tileTypeSpriteIndex.put(.floor, 309);
    try data.tileTypeSpriteIndex.put(.wall, 469);

    generateConnectedRooms();

    data.player = data.Entity{
        .x = data.rooms[0].x + @divTrunc(data.rooms[0].width, 2),
        .y = data.rooms[0].y + @divTrunc(data.rooms[0].height, 2),
        .fov = 6.55,
    };

    for (0..5) |i| {
        try data.creatures.append(data.allocator, data.Entity{ .x = data.rooms[1].x * data.tile_width + @as(i32, @intCast(i)) * data.tile_width, .y = data.rooms[1].y * data.tile_height + @as(i32, @intCast(i)) * data.tile_height, .fov = 0.0 });
    }

    data.camera = rl.Camera2D{ .target = rl.Vector2{ .x = @as(f32, @floatFromInt(data.player.x * data.tile_width)), .y = @as(f32, @floatFromInt(data.player.y * data.tile_height)) }, .offset = rl.Vector2{ .x = @as(f32, @floatFromInt(data.screen_width / 2)) - data.tile_width * 0.5, .y = @as(f32, @floatFromInt(data.screen_height / 2)) - data.tile_height * 0.5 }, .rotation = 0.0, .zoom = 1.0 };

    rl.playMusicStream(data.music[0]);
}

pub fn gameUpdate() anyerror!void {
    rl.updateMusicStream(data.music[0]);

    const fov_to_int = @as(i32, @intFromFloat(data.player.fov)) + 2;

    var start_x = data.player.x - fov_to_int;

    var start_y = data.player.y - fov_to_int;

    if (start_x < 0) {
        start_x = 0;
    }

    if (start_y < 0) {
        start_y = 0;
    }

    for (@abs(start_x)..@abs(data.player.x + fov_to_int)) |x| {
        for (@abs(start_y)..@abs(data.player.y + fov_to_int)) |y| {
            if (insideMap(@as(i32, @intCast(x)), @as(i32, @intCast(y))) and insideCircle(@floatFromInt(data.player.x), @floatFromInt(data.player.y), @floatFromInt(x), @floatFromInt(y), data.player.fov)) {
                try data.tiles_seen.put(@abs(y * data.map_width + x), {});
            }
        }
    }

    if (rl.isKeyPressed(.left)) {
        movePlayer(-1, 0);
    } else if (rl.isKeyPressed(.right)) {
        movePlayer(1, 0);
    } else if (rl.isKeyPressed(.up)) {
        movePlayer(0, -1);
    } else if (rl.isKeyPressed(.down)) {
        movePlayer(0, 1);
    }

    if (rl.isKeyDown(.kp_4)) {
        movePlayer(-1, 0);
    } else if (rl.isKeyDown(.kp_6)) {
        movePlayer(1, 0);
    } else if (rl.isKeyDown(.kp_8)) {
        movePlayer(0, -1);
    } else if (rl.isKeyDown(.kp_2)) {
        movePlayer(0, 1);
    }

    if (rl.isKeyPressed(.e)) {
        generateConnectedRooms();

        data.player.x = data.rooms[0].x + @divTrunc(data.rooms[0].width, 2);
        data.player.y = data.rooms[0].y + @divTrunc(data.rooms[0].height, 2);
    }

    const wheel = rl.getMouseWheelMove();

    if (wheel != 0) {
        const zoomIncrement = 0.125;
        data.camera.zoom += (wheel * zoomIncrement);

        if (data.camera.zoom < 0.125) {
            data.camera.zoom = 0.125;
        }
        if (data.camera.zoom > 5.0) {
            data.camera.zoom = 5.0;
        }
    }

    data.camera.target = rl.Vector2{ .x = @as(f32, @floatFromInt(data.player.x * data.tile_width)), .y = @as(f32, @floatFromInt(data.player.y * data.tile_height)) };
    data.camera.offset = rl.Vector2{ .x = @as(f32, @floatFromInt(data.screen_width / 2)) - data.tile_width * data.camera.zoom * 0.5, .y = @as(f32, @floatFromInt(data.screen_height / 2)) - data.tile_height * data.camera.zoom * 0.5 };
}

pub fn gameRender() void {
    rl.beginTextureMode(data.fog_of_war);
    rl.clearBackground(.blank);

    // render visible part of map tile by tile

    var start_x = data.player.x - 80;
    var end_x = data.player.x + 80;

    var start_y = data.player.y - 50;
    var end_y = data.player.y + 50;

    if (start_x < 0) {
        start_x = 0;
    }
    if (end_x > data.map_width) {
        end_x = data.map_width;
    }
    if (start_y < 0) {
        start_y = 0;
    }
    if (end_y > data.map_height) {
        end_y = data.map_height;
    }

    var x = start_x;

    while (x <= end_x) {
        var y = start_y;
        while (y <= end_y) {
            if (!insideCircle(@floatFromInt(data.player.x), @floatFromInt(data.player.y), @floatFromInt(x), @floatFromInt(y), data.player.fov)) {
                if (x > 0 and y > 0 and data.tiles_seen.contains(@abs(y) * data.map_width + @abs(x))) {
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
    rl.beginMode2D(data.camera);

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
    const source_rect_map = rl.Rectangle{ .x = 0.0, .y = 0.0, .width = @as(f32, @floatFromInt(data.map_texture.texture.width)), .height = -@as(f32, @floatFromInt(data.map_texture.texture.height)) };
    const dest_rect_map = rl.Rectangle{ .x = 0.0, .y = 0.0, .width = @as(f32, @floatFromInt(data.map_width * data.tile_width)), .height = @as(f32, @floatFromInt(data.map_height * data.tile_height)) };
    const origin_map = rl.Vector2{ .x = 0, .y = 0 };
    rl.drawTexturePro(data.map_texture.texture, source_rect_map, dest_rect_map, origin_map, 0.0, .white);

    // render creatures
    for (data.creatures.items) |creature| {
        drawTile(@as(f32, @floatFromInt(creature.x)), @as(f32, @floatFromInt(creature.y)), 8, 94);
    }

    // render player
    drawTile(data.camera.target.x, data.camera.target.y, 36, 84);
    drawTile(data.camera.target.x, data.camera.target.y, 5, 80);
    drawTile(data.camera.target.x, data.camera.target.y, 50, 82);
    drawTile(data.camera.target.x, data.camera.target.y, 34, 90);

    const source_rect_fog = rl.Rectangle{ .x = 0.0, .y = 0.0, .width = @as(f32, @floatFromInt(data.fog_of_war.texture.width)), .height = -@as(f32, @floatFromInt(data.fog_of_war.texture.height)) };

    rl.drawTexturePro(data.fog_of_war.texture, source_rect_fog, dest_rect_map, origin_map, 0.0, .white);

    rl.endMode2D();

    rl.drawRectangle(5, 5, 330, 120, Color.fade(Color.sky_blue, 0.5));
    rl.drawRectangleLines(5, 5, 330, 120, Color.blue);

    rl.drawText(rl.textFormat("Camera Target: %06.2f , %06.2f", .{ data.camera.target.x, data.camera.target.y }), 15, 10, 14, Color.yellow);
    rl.drawText(rl.textFormat("Camera zoom: %06.2f", .{data.camera.zoom}), 15, 30, 14, Color.yellow);
    rl.endDrawing();
}

pub fn gameShutdown() void {
    data.tiles_seen.deinit();
    data.tileTypeSpriteIndex.deinit();
    data.creatures.deinit(data.allocator);
    rl.unloadTexture(data.tilesheet);
    rl.unloadRenderTexture(data.fog_of_war);
    rl.unloadSound(data.sounds[0]);
    rl.stopMusicStream(data.music[0]);
    rl.unloadMusicStream(data.music[0]);
    rl.closeAudioDevice();
    rl.closeWindow(); // Close window and OpenGL context
}

pub fn drawTile(x_pos: f32, y_pos: f32, texture_index_x: i32, texture_index_y: i32) void {
    const source_rect = rl.Rectangle{ .x = @as(f32, @floatFromInt(texture_index_x * data.tile_width)), .y = @as(f32, @floatFromInt(texture_index_y * data.tile_height)), .width = @as(f32, @floatFromInt(data.tile_width)), .height = @as(f32, @floatFromInt(data.tile_height)) };
    const dest_rect = rl.Rectangle{ .x = x_pos, .y = y_pos, .width = @as(f32, @floatFromInt(data.tile_width)), .height = @as(f32, @floatFromInt(data.tile_height)) };
    const origin = rl.Vector2{ .x = 0, .y = 0 };
    rl.drawTexturePro(data.tilesheet, source_rect, dest_rect, origin, 0.0, Color.white);
}

pub fn generateConnectedRooms() void {
    data.tiles_seen.clearAndFree();
    for (0..data.map_width * data.map_height) |i| {
        if (mapIndexToX(i) == 0 or mapIndexToX(i) == data.map_width - 1 or mapIndexToY(i) == 0 or mapIndexToY(i) == data.map_height - 1) {
            data.map[i] = data.TileType.nothing;
        } else {
            data.map[i] = data.TileType.wall;
        }
    }

    const bound_x: i32 = data.map_width - 1;
    const bound_y: i32 = data.map_height - 1;

    const max_room_width: i32 = 10;
    const max_room_height: i32 = 10;
    const min_room_width: i32 = 4;
    const min_room_height: i32 = 4;

    data.rooms = undefined;

    data.rooms[0] = data.Rectangle{ .x = rl.getRandomValue(1, bound_x - max_room_width), .y = rl.getRandomValue(1, bound_y - max_room_height), .width = rl.getRandomValue(min_room_width, max_room_width), .height = rl.getRandomValue(min_room_height, max_room_height) };

    const actual_rooms: i32 = data.max_rooms;
    var rooms_index: i32 = 1;
    var tries: i32 = 0;

    while (rooms_index < actual_rooms and tries < data.max_rooms) {
        var room_overlaps = false;

        const new_room =
            data.Rectangle{ .x = rl.getRandomValue(1, bound_x - max_room_width), .y = rl.getRandomValue(1, bound_y - max_room_height), .width = rl.getRandomValue(min_room_width, max_room_width), .height = rl.getRandomValue(min_room_height, max_room_height) };

        for (0..@abs(rooms_index)) |i| {
            const old_room = data.rooms[i];

            if (old_room.x + old_room.width >= new_room.x and
                old_room.x <= new_room.x + new_room.width and
                old_room.y + old_room.height >= new_room.y and
                old_room.y <= new_room.y + new_room.height)
            {
                room_overlaps = true;
            }
        }

        if (!room_overlaps) {
            data.rooms[@abs(rooms_index)] = new_room;
            rooms_index += 1;
        }

        tries += 1;
    }

    for (0..@abs(rooms_index)) |i| {
        const this_room = data.rooms[i];

        for (@abs(this_room.x)..@abs(this_room.x + this_room.width)) |x| {
            for (@abs(this_room.y)..@abs(this_room.y + this_room.height)) |y| {
                data.map[y * data.map_width + x] = .floor;
            }
        }

        if (i < rooms_index - 1) {
            const next_room = data.rooms[i + 1];

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
                data.map[@abs(this_room_middle_y) * data.map_width + @abs(start_x)] = .floor;
            }
            while (start_y != end_y) {
                if (start_y < end_y) {
                    start_y += 1;
                } else {
                    start_y -= 1;
                }
                data.map[@abs(start_y) * data.map_width + @abs(next_room_middle_x)] = .floor;
            }
        }
    }

    data.player.x = data.rooms[0].x + @divTrunc((data.rooms[0].width), 2);
    data.player.y = data.rooms[0].y + @divTrunc((data.rooms[0].height), 2);

    rl.beginTextureMode(data.map_texture);
    rl.clearBackground(.blank);

    for (0..data.map_width) |x| {
        for (0..data.map_height) |y| {
            const tileType = data.map[y * data.map_width + x];
            if (tileType == .floor) {
                const source_rect = rl.Rectangle{ .x = @as(f32, @floatFromInt(spriteIndexToX(.floor) * data.tile_width)), .y = @as(f32, @floatFromInt(spriteIndexToY(.floor) * data.tile_height)), .width = @as(f32, @floatFromInt(data.tile_width)), .height = @as(f32, @floatFromInt(data.tile_height)) };
                const dest_rect = rl.Rectangle{ .x = @as(f32, @floatFromInt(x * data.tile_width)), .y = @as(f32, @floatFromInt(y * data.tile_height)), .width = @as(f32, @floatFromInt(data.tile_width)), .height = @as(f32, @floatFromInt(data.tile_height)) };
                const origin = rl.Vector2{ .x = 0, .y = 0 };
                rl.drawTexturePro(data.tilesheet, source_rect, dest_rect, origin, 0.0, Color.white);
            } else if (tileType == .wall) {
                const source_rect = rl.Rectangle{ .x = @as(f32, @floatFromInt(spriteIndexToX(.wall) * data.tile_width)), .y = @as(f32, @floatFromInt(spriteIndexToY(.wall) * data.tile_height)), .width = @as(f32, @floatFromInt(data.tile_width)), .height = @as(f32, @floatFromInt(data.tile_height)) };
                const dest_rect = rl.Rectangle{ .x = @as(f32, @floatFromInt(x * data.tile_width)), .y = @as(f32, @floatFromInt(y * data.tile_height)), .width = @as(f32, @floatFromInt(data.tile_width)), .height = @as(f32, @floatFromInt(data.tile_height)) };
                const origin = rl.Vector2{ .x = 0, .y = 0 };
                rl.drawTexturePro(data.tilesheet, source_rect, dest_rect, origin, 0.0, Color.white);
            } else if (tileType == .nothing) {
                const source_rect = rl.Rectangle{ .x = @as(f32, @floatFromInt(spriteIndexToX(.nothing) * data.tile_width)), .y = @as(f32, @floatFromInt(spriteIndexToY(.nothing) * data.tile_height)), .width = @as(f32, @floatFromInt(data.tile_width)), .height = @as(f32, @floatFromInt(data.tile_height)) };
                const dest_rect = rl.Rectangle{ .x = @as(f32, @floatFromInt(x * data.tile_width)), .y = @as(f32, @floatFromInt(y * data.tile_height)), .width = @as(f32, @floatFromInt(data.tile_width)), .height = @as(f32, @floatFromInt(data.tile_height)) };
                const origin = rl.Vector2{ .x = 0, .y = 0 };
                rl.drawTexturePro(data.tilesheet, source_rect, dest_rect, origin, 0.0, Color.white);
            }
        }
    }

    rl.endTextureMode();
}

pub fn movePlayer(x_offset: i32, y_offset: i32) void {
    const new_x = data.player.x + x_offset;
    const new_y = data.player.y + y_offset;

    if (data.map[@abs(new_y) * data.map_width + @abs(new_x)] == .floor) {
        data.player.x += x_offset;
        data.player.y += y_offset;
    }
}

pub fn insideCircle(center_x: f32, center_y: f32, x: f32, y: f32, radius: f32) bool {
    const dx = center_x - x;
    const dy = center_y - y;
    const distance = std.math.sqrt(dx * dx + dy * dy);
    return distance <= radius;
}

pub fn insideMap(x: i32, y: i32) bool {
    return x >= 0 and x < data.map_width and y >= 0 and y < data.map_height;
}

pub fn spriteIndexToX(tileType: data.TileType) u16 {
    const spriteIndex = data.tileTypeSpriteIndex.get(tileType);
    return spriteIndex.? % 64;
}

pub fn spriteIndexToY(tileType: data.TileType) u16 {
    const spriteIndex = data.tileTypeSpriteIndex.get(tileType);
    return @divFloor(spriteIndex.?, 64);
}

pub fn mapIndexToX(index: usize) usize {
    return index % data.map_width;
}

pub fn mapIndexToY(index: usize) usize {
    return @divFloor(index, data.map_width);
}
