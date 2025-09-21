const std = @import("std");
const rl = @import("raylib");
const dt = @import("datatypes.zig");

pub const screen_width = 1280;
pub const screen_height = 720;

pub const map_width = 100;
pub const map_height = 100;
pub const max_rooms = 50;

pub const tile_width = 32;
pub const tile_height = 32;

pub var tilesheet: rl.Texture2D = undefined;

pub var map_texture: rl.RenderTexture = undefined;
pub var fog_of_war: rl.RenderTexture = undefined;

const max_sounds = 5;
pub var sounds: [max_sounds]rl.Sound = undefined;

const max_music = 2;
pub var music: [max_music]rl.Music = undefined;

pub var gpa = std.heap.GeneralPurposeAllocator(.{}){};
pub const allocator = gpa.allocator();

pub const TileType = enum(u8) { nothing, floor, wall };
pub var tileTypeSpriteIndex = std.AutoHashMap(TileType, u16).init(allocator);

pub var map: [map_width * map_width]TileType = undefined;
pub var rooms: [max_rooms]dt.Rectangle = undefined;
pub var tiles_seen = std.AutoArrayHashMap(usize, void).init(allocator);

pub var camera: rl.Camera2D = undefined;
pub var player: dt.Entity = undefined;

pub var creatures: std.ArrayListUnmanaged(dt.Entity) = .empty;
