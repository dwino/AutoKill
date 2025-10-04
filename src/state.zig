const std = @import("std");
const rl = @import("raylib");
const Color = rl.Color;
const cs = @import("constants.zig");
const dt = @import("datatypes.zig");
const l = @import("logic.zig");

var tilesheet: rl.Texture2D = undefined;

var map_texture: rl.RenderTexture = undefined;
var fog_of_war: rl.RenderTexture = undefined;

var sounds: [cs.max_sounds]rl.Sound = undefined;

var music: [cs.max_music]rl.Music = undefined;

var tileTypeSpriteIndex = std.AutoHashMap(dt.TileType, u16).init(cs.allocator);

var map: [cs.map_width * cs.map_width]dt.TileType = undefined;
var next_map: [cs.map_width * cs.map_width]dt.TileType = undefined;

var rooms: [cs.max_rooms]dt.Rectangle = undefined;
var next_rooms: [cs.max_rooms]dt.Rectangle = undefined;

var tiles_seen = std.AutoArrayHashMap(usize, void).init(cs.allocator);

var camera: rl.Camera2D = undefined;
var player: dt.Position = undefined;

// var creatures: std.ArrayListUnmanaged(dt.Position) = .empty;

var creatures = dt.Creatures{
    .max_index = undefined,
    .id = undefined,
    .position = undefined,
    .health = undefined,
};

var thread: std.Thread = undefined;

// GAME STARTUP
pub fn gameStartup() anyerror!void {
    rl.initWindow(
        cs.screen_width,
        cs.screen_height,
        cs.title,
    );
    rl.initAudioDevice();

    const image: rl.Image = try rl.loadImage("tilesheet.png");
    tilesheet = try rl.loadTextureFromImage(image);
    rl.unloadImage(image);

    // d.sounds[0] = try rl.loadSound("Audio/footstep00.ogg");
    music[0] = try rl.loadMusicStream("Music/metal1.mp3");

    map_texture = try rl.loadRenderTexture(cs.map_width * cs.tile_width, cs.map_height * cs.tile_height);

    fog_of_war = try rl.loadRenderTexture(cs.map_width, cs.map_height);
    rl.setTextureFilter(fog_of_war.texture, .bilinear);

    rl.setTargetFPS(60);

    try tileTypeSpriteIndex.put(.nothing, 18);
    try tileTypeSpriteIndex.put(.floor, 309);
    try tileTypeSpriteIndex.put(.wall, 469);

    try connectedRoomsMap();

    thread = try std.Thread.spawn(.{}, prepareNextMap, .{});

    // thread = try std.Thread.spawn(.{}, prepareNextMap(), .{});

    camera = rl.Camera2D{ .target = rl.Vector2{ .x = @as(f32, @floatFromInt(player.x * cs.tile_width)), .y = @as(f32, @floatFromInt(player.y * cs.tile_height)) }, .offset = rl.Vector2{ .x = @as(f32, @floatFromInt(cs.screen_width / 2)) - cs.tile_width * 0.5, .y = @as(f32, @floatFromInt(cs.screen_height / 2)) - cs.tile_height * 0.5 }, .rotation = 0.0, .zoom = 1.0 };

    rl.playMusicStream(music[0]);
}

pub fn connectedRoomsMap() anyerror!void {
    tiles_seen.clearAndFree();

    rooms = l.generateNonOverlappingRoomsInternalRNG();

    map = l.prepareMapAndConnectRooms(rooms);

    player = dt.Position{
        .x = rooms[0].x + @divTrunc(rooms[0].width, 2),
        .y = rooms[0].y + @divTrunc(rooms[0].height, 2),
    };

    storeMapTexture();

    creatures = try l.populateMap(rooms);
}

pub fn prepareNextMap() void {
    std.debug.print("this is a new thread", .{});
    next_rooms = l.generateNonOverlappingRoomsInternalRNG();
    next_map = l.prepareMapAndConnectRooms(next_rooms);
}

pub fn activateNextMap() anyerror!void {
    tiles_seen.clearAndFree();

    rooms = next_rooms;

    map = next_map;

    player = dt.Position{
        .x = rooms[0].x + @divTrunc(rooms[0].width, 2),
        .y = rooms[0].y + @divTrunc(rooms[0].height, 2),
    };

    storeMapTexture();

    creatures = try l.populateMap(rooms);
}

pub fn storeMapTexture() void {
    rl.beginTextureMode(map_texture);
    rl.clearBackground(.blank);

    for (0..cs.map_width) |x| {
        for (0..cs.map_height) |y| {
            const tileType = map[y * cs.map_width + x];
            if (tileType == .floor) {
                const source_rect = rl.Rectangle{ .x = @as(f32, @floatFromInt(l.spriteIndexToX(getTileSpriteIndex(.floor)) * cs.tile_width)), .y = @as(f32, @floatFromInt(l.spriteIndexToY(getTileSpriteIndex(.floor)) * cs.tile_height)), .width = @as(f32, @floatFromInt(cs.tile_width)), .height = @as(f32, @floatFromInt(cs.tile_height)) };
                const dest_rect = rl.Rectangle{ .x = @as(f32, @floatFromInt(x * cs.tile_width)), .y = @as(f32, @floatFromInt(y * cs.tile_height)), .width = @as(f32, @floatFromInt(cs.tile_width)), .height = @as(f32, @floatFromInt(cs.tile_height)) };
                const origin = rl.Vector2{ .x = 0, .y = 0 };
                rl.drawTexturePro(tilesheet, source_rect, dest_rect, origin, 0.0, Color.white);
            } else if (tileType == .wall) {
                const source_rect = rl.Rectangle{ .x = @as(f32, @floatFromInt(l.spriteIndexToX(getTileSpriteIndex(.wall)) * cs.tile_width)), .y = @as(f32, @floatFromInt(l.spriteIndexToY(getTileSpriteIndex(.wall)) * cs.tile_height)), .width = @as(f32, @floatFromInt(cs.tile_width)), .height = @as(f32, @floatFromInt(cs.tile_height)) };
                const dest_rect = rl.Rectangle{ .x = @as(f32, @floatFromInt(x * cs.tile_width)), .y = @as(f32, @floatFromInt(y * cs.tile_height)), .width = @as(f32, @floatFromInt(cs.tile_width)), .height = @as(f32, @floatFromInt(cs.tile_height)) };
                const origin = rl.Vector2{ .x = 0, .y = 0 };
                rl.drawTexturePro(tilesheet, source_rect, dest_rect, origin, 0.0, Color.white);
            } else if (tileType == .nothing) {
                const source_rect = rl.Rectangle{ .x = @as(f32, @floatFromInt(l.spriteIndexToX(getTileSpriteIndex(.nothing)) * cs.tile_width)), .y = @as(f32, @floatFromInt(l.spriteIndexToY(getTileSpriteIndex(.nothing)) * cs.tile_height)), .width = @as(f32, @floatFromInt(cs.tile_width)), .height = @as(f32, @floatFromInt(cs.tile_height)) };
                const dest_rect = rl.Rectangle{ .x = @as(f32, @floatFromInt(x * cs.tile_width)), .y = @as(f32, @floatFromInt(y * cs.tile_height)), .width = @as(f32, @floatFromInt(cs.tile_width)), .height = @as(f32, @floatFromInt(cs.tile_height)) };
                const origin = rl.Vector2{ .x = 0, .y = 0 };
                rl.drawTexturePro(tilesheet, source_rect, dest_rect, origin, 0.0, Color.white);
            }
        }
    }

    rl.endTextureMode();
}

pub fn getTileSpriteIndex(tileType: dt.TileType) u16 {
    return tileTypeSpriteIndex.get(tileType).?;
}
//////////

// GAME UPDATE

pub fn gameUpdate() anyerror!void {
    rl.updateMusicStream(music[0]);

    const fov_to_int = @as(i32, @intFromFloat(cs.player_fov)) + 2;

    var start_x = player.x - fov_to_int;

    var start_y = player.y - fov_to_int;

    if (start_x < 0) {
        start_x = 0;
    }

    if (start_y < 0) {
        start_y = 0;
    }

    for (@abs(start_x)..@abs(player.x + fov_to_int)) |x| {
        for (@abs(start_y)..@abs(player.y + fov_to_int)) |y| {
            if (l.insideMap(@as(i32, @intCast(x)), @as(i32, @intCast(y))) and l.insideCircle(@floatFromInt(player.x), @floatFromInt(player.y), @floatFromInt(x), @floatFromInt(y), cs.player_fov)) {
                try tiles_seen.put(@abs(y * cs.map_width + x), {});
            }
        }
    }

    if (rl.isKeyPressed(.left)) {
        movePlayerOrAttack(-1, 0);
    } else if (rl.isKeyPressed(.right)) {
        movePlayerOrAttack(1, 0);
    } else if (rl.isKeyPressed(.up)) {
        movePlayerOrAttack(0, -1);
    } else if (rl.isKeyPressed(.down)) {
        movePlayerOrAttack(0, 1);
    }

    if (rl.isKeyDown(.kp_4)) {
        movePlayerOrAttack(-1, 0);
    }
    if (rl.isKeyDown(.kp_6)) {
        movePlayerOrAttack(1, 0);
    }
    if (rl.isKeyDown(.kp_8)) {
        movePlayerOrAttack(0, -1);
    }
    if (rl.isKeyDown(.kp_2)) {
        movePlayerOrAttack(0, 1);
    }

    if (rl.isKeyPressed(.j)) {
        thread.join();
        try activateNextMap();
    }
    if (rl.isKeyPressed(.s)) {
        thread = try std.Thread.spawn(.{}, prepareNextMap, .{});
    }
    if (rl.isKeyPressed(.r)) {
        try connectedRoomsMap();
    }

    const wheel = rl.getMouseWheelMove();

    if (wheel != 0) {
        const zoomIncrement = 0.125;
        camera.zoom += (wheel * zoomIncrement);

        if (camera.zoom < 0.125) {
            camera.zoom = 0.125;
        }
        if (camera.zoom > 5.0) {
            camera.zoom = 5.0;
        }
    }

    camera.target = rl.Vector2{ .x = @as(f32, @floatFromInt(player.x * cs.tile_width)), .y = @as(f32, @floatFromInt(player.y * cs.tile_height)) };
    camera.offset = rl.Vector2{ .x = @as(f32, @floatFromInt(cs.screen_width / 2)) - cs.tile_width * camera.zoom * 0.5, .y = @as(f32, @floatFromInt(cs.screen_height / 2)) - cs.tile_height * camera.zoom * 0.5 };
}

pub fn movePlayerOrAttack(x_offset: i32, y_offset: i32) void {
    const new_x = player.x + x_offset;
    const new_y = player.y + y_offset;
    std.debug.print("player position: {},{}\n", .{ new_x, new_x });

    var attacked = false;
    for (0..creatures.max_index) |id| {
        const position = creatures.position[id];
        std.debug.print("enemy {} position: {},{}\n", .{ id, position.x, position.y });

        if (position.x == new_x and position.y == new_y) {
            attacked = true;
            creatures.health[id] -= 20;
        }
    }

    if (!attacked and map[@abs(new_y) * cs.map_width + @abs(new_x)] == .floor) {
        player.x += x_offset;
        player.y += y_offset;
    }
}

///////////

// GAME RENDER
pub fn gameRender() void {
    rl.beginTextureMode(fog_of_war);
    rl.clearBackground(.blank);

    // render visible part of map tile by tile

    var start_x = player.x - 80;
    var end_x = player.x + 80;

    var start_y = player.y - 50;
    var end_y = player.y + 50;

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
            if (!l.insideCircle(@floatFromInt(player.x), @floatFromInt(player.y), @floatFromInt(x), @floatFromInt(y), cs.player_fov)) {
                if (x > 0 and y > 0 and tiles_seen.contains(@abs(y) * cs.map_width + @abs(x))) {
                    rl.drawRectangle(@intCast(x), @intCast(y), 1, 1, rl.fade(.black, 0.5));
                } else {
                    rl.drawRectangle(@intCast(x), @intCast(y), 1, 1, .black);
                }
            }

            y += 1;
        }
        x += 1;
    }

    rl.endTextureMode();

    rl.beginDrawing();
    rl.clearBackground(Color.black);
    rl.beginMode2D(camera);

    // render map
    const source_rect_map = rl.Rectangle{ .x = 0.0, .y = 0.0, .width = @as(f32, @floatFromInt(map_texture.texture.width)), .height = -@as(f32, @floatFromInt(map_texture.texture.height)) };
    const dest_rect_map = rl.Rectangle{ .x = 0.0, .y = 0.0, .width = @as(f32, @floatFromInt(cs.map_width * cs.tile_width)), .height = @as(f32, @floatFromInt(cs.map_height * cs.tile_height)) };
    const origin_map = rl.Vector2{ .x = 0, .y = 0 };
    rl.drawTexturePro(map_texture.texture, source_rect_map, dest_rect_map, origin_map, 0.0, .white);

    // render creatures
    for (creatures.position) |position| {
        drawTile(@as(f32, @floatFromInt(position.x * cs.tile_width)), @as(f32, @floatFromInt(position.y * cs.tile_height)), 8, 94);
    }

    // render player
    drawTile(camera.target.x, camera.target.y, 36, 84);
    drawTile(camera.target.x, camera.target.y, 5, 80);
    drawTile(camera.target.x, camera.target.y, 50, 82);
    drawTile(camera.target.x, camera.target.y, 34, 90);

    const source_rect_fog = rl.Rectangle{ .x = 0.0, .y = 0.0, .width = @as(f32, @floatFromInt(fog_of_war.texture.width)), .height = -@as(f32, @floatFromInt(fog_of_war.texture.height)) };

    rl.drawTexturePro(fog_of_war.texture, source_rect_fog, dest_rect_map, origin_map, 0.0, .white);

    rl.endMode2D();

    rl.drawRectangle(5, 5, 330, 120, Color.fade(Color.sky_blue, 0.5));
    rl.drawRectangleLines(5, 5, 330, 120, Color.blue);

    rl.drawText(rl.textFormat("Camera Target: %06.2f , %06.2f", .{ camera.target.x, camera.target.y }), 15, 10, 14, Color.yellow);
    rl.drawText(rl.textFormat("Camera zoom: %06.2f", .{camera.zoom}), 15, 30, 14, Color.yellow);
    rl.endDrawing();
}

pub fn drawTile(x_pos: f32, y_pos: f32, texture_index_x: i32, texture_index_y: i32) void {
    const source_rect = rl.Rectangle{ .x = @as(f32, @floatFromInt(texture_index_x * cs.tile_width)), .y = @as(f32, @floatFromInt(texture_index_y * cs.tile_height)), .width = @as(f32, @floatFromInt(cs.tile_width)), .height = @as(f32, @floatFromInt(cs.tile_height)) };
    const dest_rect = rl.Rectangle{ .x = x_pos, .y = y_pos, .width = @as(f32, @floatFromInt(cs.tile_width)), .height = @as(f32, @floatFromInt(cs.tile_height)) };
    const origin = rl.Vector2{ .x = 0, .y = 0 };
    rl.drawTexturePro(tilesheet, source_rect, dest_rect, origin, 0.0, Color.white);
}

///////////

// GAME SHUTDOWN
pub fn gameShutdown() void {
    tiles_seen.deinit();
    tileTypeSpriteIndex.deinit();
    rl.unloadTexture(tilesheet);
    rl.unloadRenderTexture(fog_of_war);
    //rl.unloadSound(d.sounds[0]);
    rl.stopMusicStream(music[0]);
    rl.unloadMusicStream(music[0]);
    rl.closeAudioDevice();
    rl.closeWindow(); // Close window and OpenGL context
}
