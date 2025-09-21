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

    try creatures.appendSlice(cs.allocator, new_creatures_slice);

    camera = rl.Camera2D{ .target = rl.Vector2{ .x = @as(f32, @floatFromInt(player.x * cs.tile_width)), .y = @as(f32, @floatFromInt(player.y * cs.tile_height)) }, .offset = rl.Vector2{ .x = @as(f32, @floatFromInt(cs.screen_width / 2)) - cs.tile_width * 0.5, .y = @as(f32, @floatFromInt(cs.screen_height / 2)) - cs.tile_height * 0.5 }, .rotation = 0.0, .zoom = 1.0 };

    rl.playMusicStream(music[0]);
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
