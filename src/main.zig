const std = @import("std");
const Window = @import("Window.zig");

pub fn main() !void {
    var window = try Window.init();
    defer window.deinit();

    try window.run();
}
