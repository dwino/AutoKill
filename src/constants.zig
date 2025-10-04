const std = @import("std");

pub const title = "AutoKill";

pub const screen_width = 1920;
pub const screen_height = 1080;

pub const map_width = 100;
pub const map_height = 100;
pub const max_rooms = 50;
pub const bound_x_left: i32 = 2;
pub const bound_x_right: i32 = map_width - 1;
pub const bound_y_up: i32 = 2;
pub const bound_y_down: i32 = map_height - 1;

pub const max_room_width: i32 = 10;
pub const max_room_height: i32 = 10;
pub const min_room_width: i32 = 4;
pub const min_room_height: i32 = 4;

pub const tile_width = 32;
pub const tile_height = 32;

pub const max_creatures = 100;

pub const max_sounds = 5;

pub const max_music = 2;

pub var gpa = std.heap.GeneralPurposeAllocator(.{}){};
pub const allocator = gpa.allocator();

pub const player_fov = 6.55;
