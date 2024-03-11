const std = @import("std");

const Core = @This();

const State = struct {
    kibble: u64,
    wood: u64,
};

state: State,

pub fn init() Core {
    return .{
        .state = .{
            .kibble = 0,
            .wood = 0,
        },
    };
}

pub fn deinit(self: Core) void {
    _ = self;
}

pub fn tick(self: *Core) void {
    self.state.kibble += 1;
}
