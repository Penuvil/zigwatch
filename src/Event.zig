const std = @import("std");
const builtin = @import("builtin");

const WatchHandle = @import("Watcher.zig").WatchHandle;

pub const EventType = enum {
    Create,
    Modify,
    Delete,
};

pub const EventFilter = struct {
    create: bool = false,
    modify: bool = false,
    delete: bool = false,
};

pub const Event = struct {
    handle: WatchHandle,
    type: EventType,
    path: []const u8,
    timestamp: i64,
    extra: ?EventExtra,
};

pub const EventExtra = union {
    cookie: u32,
    flags: u64,
    reserved: void,
};
