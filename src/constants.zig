const std = @import("std");

pub const screen_width = 1280;
pub const screen_height = 720;

pub const map_width = 100;
pub const map_height = 100;
pub const max_rooms = 50;

pub const tile_width = 32;
pub const tile_height = 32;

pub const max_sounds = 5;

pub const max_music = 2;

pub var gpa = std.heap.GeneralPurposeAllocator(.{}){};
pub const allocator = gpa.allocator();
