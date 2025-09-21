const std = @import("std");
const rl = @import("raylib");
const Color = rl.Color;
const cs = @import("constants.zig");
const dt = @import("datatypes.zig");
const l = @import("logic.zig");

pub var tilesheet: rl.Texture2D = undefined;

pub var map_texture: rl.RenderTexture = undefined;
pub var fog_of_war: rl.RenderTexture = undefined;

pub var sounds: [cs.max_sounds]rl.Sound = undefined;

pub var music: [cs.max_music]rl.Music = undefined;

pub var tileTypeSpriteIndex = std.AutoHashMap(dt.TileType, u16).init(cs.allocator);

pub var map: [cs.map_width * cs.map_width]dt.TileType = undefined;
pub var rooms: [cs.max_rooms]dt.Rectangle = undefined;
pub var tiles_seen = std.AutoArrayHashMap(usize, void).init(cs.allocator);

pub var camera: rl.Camera2D = undefined;
pub var player: dt.Entity = undefined;

pub var creatures: std.ArrayListUnmanaged(dt.Entity) = .empty;

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

    camera = rl.Camera2D{ .target = rl.Vector2{ .x = @as(f32, @floatFromInt(player.x * cs.tile_width)), .y = @as(f32, @floatFromInt(player.y * cs.tile_height)) }, .offset = rl.Vector2{ .x = @as(f32, @floatFromInt(cs.screen_width / 2)) - cs.tile_width * 0.5, .y = @as(f32, @floatFromInt(cs.screen_height / 2)) - cs.tile_height * 0.5 }, .rotation = 0.0, .zoom = 1.0 };

    rl.playMusicStream(music[0]);
}

pub fn connectedRoomsMap() anyerror!void {
    tiles_seen.clearAndFree();

    rooms = l.generateNonOverlappingRooms();

    map = l.prepareMapAndConnectRooms(rooms);

    player = dt.Entity{
        .x = rooms[0].x + @divTrunc(rooms[0].width, 2),
        .y = rooms[0].y + @divTrunc(rooms[0].height, 2),
        .fov = 6.55,
    };

    storeMapTexture();

    const new_creatures_slice = try l.populateMap(rooms, cs.allocator);

    creatures.clearAndFree(cs.allocator);

    try creatures.appendSlice(cs.allocator, new_creatures_slice);
}

pub fn storeMapTexture() void {
    rl.beginTextureMode(map_texture);
    rl.clearBackground(.blank);

    for (0..cs.map_width) |x| {
        for (0..cs.map_height) |y| {
            const tileType = map[y * cs.map_width + x];
            if (tileType == .floor) {
                const source_rect = rl.Rectangle{ .x = @as(f32, @floatFromInt(l.spriteIndexToX(.floor) * cs.tile_width)), .y = @as(f32, @floatFromInt(l.spriteIndexToY(.floor) * cs.tile_height)), .width = @as(f32, @floatFromInt(cs.tile_width)), .height = @as(f32, @floatFromInt(cs.tile_height)) };
                const dest_rect = rl.Rectangle{ .x = @as(f32, @floatFromInt(x * cs.tile_width)), .y = @as(f32, @floatFromInt(y * cs.tile_height)), .width = @as(f32, @floatFromInt(cs.tile_width)), .height = @as(f32, @floatFromInt(cs.tile_height)) };
                const origin = rl.Vector2{ .x = 0, .y = 0 };
                rl.drawTexturePro(tilesheet, source_rect, dest_rect, origin, 0.0, Color.white);
            } else if (tileType == .wall) {
                const source_rect = rl.Rectangle{ .x = @as(f32, @floatFromInt(l.spriteIndexToX(.wall) * cs.tile_width)), .y = @as(f32, @floatFromInt(l.spriteIndexToY(.wall) * cs.tile_height)), .width = @as(f32, @floatFromInt(cs.tile_width)), .height = @as(f32, @floatFromInt(cs.tile_height)) };
                const dest_rect = rl.Rectangle{ .x = @as(f32, @floatFromInt(x * cs.tile_width)), .y = @as(f32, @floatFromInt(y * cs.tile_height)), .width = @as(f32, @floatFromInt(cs.tile_width)), .height = @as(f32, @floatFromInt(cs.tile_height)) };
                const origin = rl.Vector2{ .x = 0, .y = 0 };
                rl.drawTexturePro(tilesheet, source_rect, dest_rect, origin, 0.0, Color.white);
            } else if (tileType == .nothing) {
                const source_rect = rl.Rectangle{ .x = @as(f32, @floatFromInt(l.spriteIndexToX(.nothing) * cs.tile_width)), .y = @as(f32, @floatFromInt(l.spriteIndexToY(.nothing) * cs.tile_height)), .width = @as(f32, @floatFromInt(cs.tile_width)), .height = @as(f32, @floatFromInt(cs.tile_height)) };
                const dest_rect = rl.Rectangle{ .x = @as(f32, @floatFromInt(x * cs.tile_width)), .y = @as(f32, @floatFromInt(y * cs.tile_height)), .width = @as(f32, @floatFromInt(cs.tile_width)), .height = @as(f32, @floatFromInt(cs.tile_height)) };
                const origin = rl.Vector2{ .x = 0, .y = 0 };
                rl.drawTexturePro(tilesheet, source_rect, dest_rect, origin, 0.0, Color.white);
            }
        }
    }

    rl.endTextureMode();
}

pub fn gameUpdate() anyerror!void {
    rl.updateMusicStream(music[0]);

    const fov_to_int = @as(i32, @intFromFloat(player.fov)) + 2;

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
            if (l.insideMap(@as(i32, @intCast(x)), @as(i32, @intCast(y))) and l.insideCircle(@floatFromInt(player.x), @floatFromInt(player.y), @floatFromInt(x), @floatFromInt(y), player.fov)) {
                try tiles_seen.put(@abs(y * cs.map_width + x), {});
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
    }
    if (rl.isKeyDown(.kp_6)) {
        movePlayer(1, 0);
    }
    if (rl.isKeyDown(.kp_8)) {
        movePlayer(0, -1);
    }
    if (rl.isKeyDown(.kp_2)) {
        movePlayer(0, 1);
    }

    if (rl.isKeyPressed(.e)) {
        player.x = rooms[0].x + @divTrunc(rooms[0].width, 2);
        player.y = rooms[0].y + @divTrunc(rooms[0].height, 2);
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

pub fn movePlayer(x_offset: i32, y_offset: i32) void {
    const new_x = player.x + x_offset;
    const new_y = player.y + y_offset;

    if (map[@abs(new_y) * cs.map_width + @abs(new_x)] == .floor) {
        player.x += x_offset;
        player.y += y_offset;
    }
}
