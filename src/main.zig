const std = @import("std");
const rl = @import("raylib");
const Color = rl.Color;
const d = @import("data.zig");

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
        d.screen_width,
        d.screen_height,
        "AutoKill",
    );
    rl.initAudioDevice();

    const image: rl.Image = try rl.loadImage("tilesheet.png");
    d.tilesheet = try rl.loadTextureFromImage(image);
    rl.unloadImage(image);

    // d.sounds[0] = try rl.loadSound("Audio/footstep00.ogg");
    d.music[0] = try rl.loadMusicStream("Music/metal1.mp3");

    d.map_texture = try rl.loadRenderTexture(d.map_width * d.tile_width, d.map_height * d.tile_height);

    d.fog_of_war = try rl.loadRenderTexture(d.map_width, d.map_height);
    rl.setTextureFilter(d.fog_of_war.texture, .bilinear);

    rl.setTargetFPS(60);

    try d.tileTypeSpriteIndex.put(.nothing, 18);
    try d.tileTypeSpriteIndex.put(.floor, 309);
    try d.tileTypeSpriteIndex.put(.wall, 469);

    generateConnectedRooms();

    d.player = d.Entity{
        .x = d.rooms[0].x + @divTrunc(d.rooms[0].width, 2),
        .y = d.rooms[0].y + @divTrunc(d.rooms[0].height, 2),
        .fov = 6.55,
    };

    for (0..5) |i| {
        try d.creatures.append(d.allocator, d.Entity{ .x = d.rooms[1].x * d.tile_width + @as(i32, @intCast(i)) * d.tile_width, .y = d.rooms[1].y * d.tile_height + @as(i32, @intCast(i)) * d.tile_height, .fov = 0.0 });
    }

    d.camera = rl.Camera2D{ .target = rl.Vector2{ .x = @as(f32, @floatFromInt(d.player.x * d.tile_width)), .y = @as(f32, @floatFromInt(d.player.y * d.tile_height)) }, .offset = rl.Vector2{ .x = @as(f32, @floatFromInt(d.screen_width / 2)) - d.tile_width * 0.5, .y = @as(f32, @floatFromInt(d.screen_height / 2)) - d.tile_height * 0.5 }, .rotation = 0.0, .zoom = 1.0 };

    rl.playMusicStream(d.music[0]);
}

pub fn gameUpdate() anyerror!void {
    rl.updateMusicStream(d.music[0]);

    const fov_to_int = @as(i32, @intFromFloat(d.player.fov)) + 2;

    var start_x = d.player.x - fov_to_int;

    var start_y = d.player.y - fov_to_int;

    if (start_x < 0) {
        start_x = 0;
    }

    if (start_y < 0) {
        start_y = 0;
    }

    for (@abs(start_x)..@abs(d.player.x + fov_to_int)) |x| {
        for (@abs(start_y)..@abs(d.player.y + fov_to_int)) |y| {
            if (insideMap(@as(i32, @intCast(x)), @as(i32, @intCast(y))) and insideCircle(@floatFromInt(d.player.x), @floatFromInt(d.player.y), @floatFromInt(x), @floatFromInt(y), d.player.fov)) {
                try d.tiles_seen.put(@abs(y * d.map_width + x), {});
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

        d.player.x = d.rooms[0].x + @divTrunc(d.rooms[0].width, 2);
        d.player.y = d.rooms[0].y + @divTrunc(d.rooms[0].height, 2);
    }

    const wheel = rl.getMouseWheelMove();

    if (wheel != 0) {
        const zoomIncrement = 0.125;
        d.camera.zoom += (wheel * zoomIncrement);

        if (d.camera.zoom < 0.125) {
            d.camera.zoom = 0.125;
        }
        if (d.camera.zoom > 5.0) {
            d.camera.zoom = 5.0;
        }
    }

    d.camera.target = rl.Vector2{ .x = @as(f32, @floatFromInt(d.player.x * d.tile_width)), .y = @as(f32, @floatFromInt(d.player.y * d.tile_height)) };
    d.camera.offset = rl.Vector2{ .x = @as(f32, @floatFromInt(d.screen_width / 2)) - d.tile_width * d.camera.zoom * 0.5, .y = @as(f32, @floatFromInt(d.screen_height / 2)) - d.tile_height * d.camera.zoom * 0.5 };
}

pub fn gameRender() void {
    rl.beginTextureMode(d.fog_of_war);
    rl.clearBackground(.blank);

    // render visible part of map tile by tile

    var start_x = d.player.x - 80;
    var end_x = d.player.x + 80;

    var start_y = d.player.y - 50;
    var end_y = d.player.y + 50;

    if (start_x < 0) {
        start_x = 0;
    }
    if (end_x > d.map_width) {
        end_x = d.map_width;
    }
    if (start_y < 0) {
        start_y = 0;
    }
    if (end_y > d.map_height) {
        end_y = d.map_height;
    }

    var x = start_x;

    while (x <= end_x) {
        var y = start_y;
        while (y <= end_y) {
            if (!insideCircle(@floatFromInt(d.player.x), @floatFromInt(d.player.y), @floatFromInt(x), @floatFromInt(y), d.player.fov)) {
                if (x > 0 and y > 0 and d.tiles_seen.contains(@abs(y) * d.map_width + @abs(x))) {
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
    rl.beginMode2D(d.camera);

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
    const source_rect_map = rl.Rectangle{ .x = 0.0, .y = 0.0, .width = @as(f32, @floatFromInt(d.map_texture.texture.width)), .height = -@as(f32, @floatFromInt(d.map_texture.texture.height)) };
    const dest_rect_map = rl.Rectangle{ .x = 0.0, .y = 0.0, .width = @as(f32, @floatFromInt(d.map_width * d.tile_width)), .height = @as(f32, @floatFromInt(d.map_height * d.tile_height)) };
    const origin_map = rl.Vector2{ .x = 0, .y = 0 };
    rl.drawTexturePro(d.map_texture.texture, source_rect_map, dest_rect_map, origin_map, 0.0, .white);

    // render creatures
    for (d.creatures.items) |creature| {
        drawTile(@as(f32, @floatFromInt(creature.x)), @as(f32, @floatFromInt(creature.y)), 8, 94);
    }

    // render player
    drawTile(d.camera.target.x, d.camera.target.y, 36, 84);
    drawTile(d.camera.target.x, d.camera.target.y, 5, 80);
    drawTile(d.camera.target.x, d.camera.target.y, 50, 82);
    drawTile(d.camera.target.x, d.camera.target.y, 34, 90);

    const source_rect_fog = rl.Rectangle{ .x = 0.0, .y = 0.0, .width = @as(f32, @floatFromInt(d.fog_of_war.texture.width)), .height = -@as(f32, @floatFromInt(d.fog_of_war.texture.height)) };

    rl.drawTexturePro(d.fog_of_war.texture, source_rect_fog, dest_rect_map, origin_map, 0.0, .white);

    rl.endMode2D();

    rl.drawRectangle(5, 5, 330, 120, Color.fade(Color.sky_blue, 0.5));
    rl.drawRectangleLines(5, 5, 330, 120, Color.blue);

    rl.drawText(rl.textFormat("Camera Target: %06.2f , %06.2f", .{ d.camera.target.x, d.camera.target.y }), 15, 10, 14, Color.yellow);
    rl.drawText(rl.textFormat("Camera zoom: %06.2f", .{d.camera.zoom}), 15, 30, 14, Color.yellow);
    rl.endDrawing();
}

pub fn gameShutdown() void {
    d.tiles_seen.deinit();
    d.tileTypeSpriteIndex.deinit();
    d.creatures.deinit(d.allocator);
    rl.unloadTexture(d.tilesheet);
    rl.unloadRenderTexture(d.fog_of_war);
    //rl.unloadSound(d.sounds[0]);
    rl.stopMusicStream(d.music[0]);
    rl.unloadMusicStream(d.music[0]);
    rl.closeAudioDevice();
    rl.closeWindow(); // Close window and OpenGL context
}

pub fn drawTile(x_pos: f32, y_pos: f32, texture_index_x: i32, texture_index_y: i32) void {
    const source_rect = rl.Rectangle{ .x = @as(f32, @floatFromInt(texture_index_x * d.tile_width)), .y = @as(f32, @floatFromInt(texture_index_y * d.tile_height)), .width = @as(f32, @floatFromInt(d.tile_width)), .height = @as(f32, @floatFromInt(d.tile_height)) };
    const dest_rect = rl.Rectangle{ .x = x_pos, .y = y_pos, .width = @as(f32, @floatFromInt(d.tile_width)), .height = @as(f32, @floatFromInt(d.tile_height)) };
    const origin = rl.Vector2{ .x = 0, .y = 0 };
    rl.drawTexturePro(d.tilesheet, source_rect, dest_rect, origin, 0.0, Color.white);
}

pub fn generateConnectedRooms() void {
    d.tiles_seen.clearAndFree();
    for (0..d.map_width * d.map_height) |i| {
        if (mapIndexToX(i) == 0 or mapIndexToX(i) == d.map_width - 1 or mapIndexToY(i) == 0 or mapIndexToY(i) == d.map_height - 1) {
            d.map[i] = d.TileType.nothing;
        } else {
            d.map[i] = d.TileType.wall;
        }
    }

    const bound_x: i32 = d.map_width - 1;
    const bound_y: i32 = d.map_height - 1;

    const max_room_width: i32 = 10;
    const max_room_height: i32 = 10;
    const min_room_width: i32 = 4;
    const min_room_height: i32 = 4;

    d.rooms = undefined;

    d.rooms[0] = d.Rectangle{ .x = rl.getRandomValue(1, bound_x - max_room_width), .y = rl.getRandomValue(1, bound_y - max_room_height), .width = rl.getRandomValue(min_room_width, max_room_width), .height = rl.getRandomValue(min_room_height, max_room_height) };

    const actual_rooms: i32 = d.max_rooms;
    var rooms_index: i32 = 1;
    var tries: i32 = 0;

    while (rooms_index < actual_rooms and tries < d.max_rooms) {
        var room_overlaps = false;

        const new_room =
            d.Rectangle{ .x = rl.getRandomValue(1, bound_x - max_room_width), .y = rl.getRandomValue(1, bound_y - max_room_height), .width = rl.getRandomValue(min_room_width, max_room_width), .height = rl.getRandomValue(min_room_height, max_room_height) };

        for (0..@abs(rooms_index)) |i| {
            const old_room = d.rooms[i];

            if (old_room.x + old_room.width >= new_room.x and
                old_room.x <= new_room.x + new_room.width and
                old_room.y + old_room.height >= new_room.y and
                old_room.y <= new_room.y + new_room.height)
            {
                room_overlaps = true;
            }
        }

        if (!room_overlaps) {
            d.rooms[@abs(rooms_index)] = new_room;
            rooms_index += 1;
        }

        tries += 1;
    }

    for (0..@abs(rooms_index)) |i| {
        const this_room = d.rooms[i];

        for (@abs(this_room.x)..@abs(this_room.x + this_room.width)) |x| {
            for (@abs(this_room.y)..@abs(this_room.y + this_room.height)) |y| {
                d.map[y * d.map_width + x] = .floor;
            }
        }

        if (i < rooms_index - 1) {
            const next_room = d.rooms[i + 1];

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
                d.map[@abs(this_room_middle_y) * d.map_width + @abs(start_x)] = .floor;
            }
            while (start_y != end_y) {
                if (start_y < end_y) {
                    start_y += 1;
                } else {
                    start_y -= 1;
                }
                d.map[@abs(start_y) * d.map_width + @abs(next_room_middle_x)] = .floor;
            }
        }
    }

    d.player.x = d.rooms[0].x + @divTrunc((d.rooms[0].width), 2);
    d.player.y = d.rooms[0].y + @divTrunc((d.rooms[0].height), 2);

    rl.beginTextureMode(d.map_texture);
    rl.clearBackground(.blank);

    for (0..d.map_width) |x| {
        for (0..d.map_height) |y| {
            const tileType = d.map[y * d.map_width + x];
            if (tileType == .floor) {
                const source_rect = rl.Rectangle{ .x = @as(f32, @floatFromInt(spriteIndexToX(.floor) * d.tile_width)), .y = @as(f32, @floatFromInt(spriteIndexToY(.floor) * d.tile_height)), .width = @as(f32, @floatFromInt(d.tile_width)), .height = @as(f32, @floatFromInt(d.tile_height)) };
                const dest_rect = rl.Rectangle{ .x = @as(f32, @floatFromInt(x * d.tile_width)), .y = @as(f32, @floatFromInt(y * d.tile_height)), .width = @as(f32, @floatFromInt(d.tile_width)), .height = @as(f32, @floatFromInt(d.tile_height)) };
                const origin = rl.Vector2{ .x = 0, .y = 0 };
                rl.drawTexturePro(d.tilesheet, source_rect, dest_rect, origin, 0.0, Color.white);
            } else if (tileType == .wall) {
                const source_rect = rl.Rectangle{ .x = @as(f32, @floatFromInt(spriteIndexToX(.wall) * d.tile_width)), .y = @as(f32, @floatFromInt(spriteIndexToY(.wall) * d.tile_height)), .width = @as(f32, @floatFromInt(d.tile_width)), .height = @as(f32, @floatFromInt(d.tile_height)) };
                const dest_rect = rl.Rectangle{ .x = @as(f32, @floatFromInt(x * d.tile_width)), .y = @as(f32, @floatFromInt(y * d.tile_height)), .width = @as(f32, @floatFromInt(d.tile_width)), .height = @as(f32, @floatFromInt(d.tile_height)) };
                const origin = rl.Vector2{ .x = 0, .y = 0 };
                rl.drawTexturePro(d.tilesheet, source_rect, dest_rect, origin, 0.0, Color.white);
            } else if (tileType == .nothing) {
                const source_rect = rl.Rectangle{ .x = @as(f32, @floatFromInt(spriteIndexToX(.nothing) * d.tile_width)), .y = @as(f32, @floatFromInt(spriteIndexToY(.nothing) * d.tile_height)), .width = @as(f32, @floatFromInt(d.tile_width)), .height = @as(f32, @floatFromInt(d.tile_height)) };
                const dest_rect = rl.Rectangle{ .x = @as(f32, @floatFromInt(x * d.tile_width)), .y = @as(f32, @floatFromInt(y * d.tile_height)), .width = @as(f32, @floatFromInt(d.tile_width)), .height = @as(f32, @floatFromInt(d.tile_height)) };
                const origin = rl.Vector2{ .x = 0, .y = 0 };
                rl.drawTexturePro(d.tilesheet, source_rect, dest_rect, origin, 0.0, Color.white);
            }
        }
    }

    rl.endTextureMode();
}

pub fn movePlayer(x_offset: i32, y_offset: i32) void {
    const new_x = d.player.x + x_offset;
    const new_y = d.player.y + y_offset;

    if (d.map[@abs(new_y) * d.map_width + @abs(new_x)] == .floor) {
        d.player.x += x_offset;
        d.player.y += y_offset;
    }
}

pub fn insideCircle(center_x: f32, center_y: f32, x: f32, y: f32, radius: f32) bool {
    const dx = center_x - x;
    const dy = center_y - y;
    const distance = std.math.sqrt(dx * dx + dy * dy);
    return distance <= radius;
}

pub fn insideMap(x: i32, y: i32) bool {
    return x >= 0 and x < d.map_width and y >= 0 and y < d.map_height;
}

pub fn spriteIndexToX(tileType: d.TileType) u16 {
    const spriteIndex = d.tileTypeSpriteIndex.get(tileType);
    return spriteIndex.? % 64;
}

pub fn spriteIndexToY(tileType: d.TileType) u16 {
    const spriteIndex = d.tileTypeSpriteIndex.get(tileType);
    return @divFloor(spriteIndex.?, 64);
}

pub fn mapIndexToX(index: usize) usize {
    return index % d.map_width;
}

pub fn mapIndexToY(index: usize) usize {
    return @divFloor(index, d.map_width);
}
