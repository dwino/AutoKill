const std = @import("std");
const rl = @import("raylib");
const cs = @import("constants.zig");
const dt = @import("datatypes.zig");

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
