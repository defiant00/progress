const std = @import("std");

const Core = @This();

const State = struct {
    kibble: u64,
    clay: u64,
    wood: u64,
    stone: u64,

    brick: u64,
};

state: State,

pub fn init() Core {
    return .{
        .state = .{
            .kibble = 0,
            .clay = 0,
            .wood = 0,
            .stone = 0,

            .brick = 0,
        },
    };
}

pub fn deinit(self: Core) void {
    _ = self;
}

pub fn tick(self: *Core) void {
    self.state.kibble += 1;
}
