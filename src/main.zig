const std = @import("std");
const rl = @import("raylib");
const Color = rl.Color;
const d = @import("data.zig");
const l = @import("logic.zig");

pub fn main() anyerror!void {
    try l.gameStartup();
    defer l.gameShutdown();

    while (!rl.windowShouldClose()) {
        try l.gameUpdate();
        l.gameRender();

        std.debug.print("frametime: {}\n", .{rl.getFrameTime() * 1000});
    }
}
