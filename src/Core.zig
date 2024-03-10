const std = @import("std");

const Core = @This();

const State = struct {
    catnip: u64,
    wood: u64,
};

state: State,

pub fn init() Core {
    return .{
        .state = .{
            .catnip = 0,
            .wood = 0,
        },
    };
}

pub fn deinit(self: Core) void {
    _ = self;
}

pub fn tick(self: *Core) void {
    _ = self;
}
