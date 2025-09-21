const std = @import("std");
const rl = @import("raylib");

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

pub const Entity = struct { x: i32, y: i32, fov: f32 };

pub const Rectangle = struct { x: i32, y: i32, width: i32, height: i32 };

pub var gpa = std.heap.GeneralPurposeAllocator(.{}){};
pub const allocator = gpa.allocator();

pub const TileType = enum(u8) { nothing, floor, wall };
pub var tileTypeSpriteIndex = std.AutoHashMap(TileType, u16).init(allocator);

pub var map: [map_width * map_width]TileType = undefined;
pub var rooms: [max_rooms]Rectangle = undefined;
pub var tiles_seen = std.AutoArrayHashMap(usize, void).init(allocator);

pub var camera: rl.Camera2D = undefined;
pub var player: Entity = undefined;

pub var creatures: std.ArrayListUnmanaged(Entity) = .empty;
