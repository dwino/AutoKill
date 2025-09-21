const std = @import("std");
const rl = @import("raylib");
const Color = rl.Color;
const s = @import("state.zig");
const l = @import("logic.zig");

pub fn main() anyerror!void {
    try s.gameStartup();
    defer s.gameShutdown();

    while (!rl.windowShouldClose()) {
        try s.gameUpdate();
        s.gameRender();

        std.debug.print("frametime: {}\n", .{rl.getFrameTime() * 1000});
    }
}
