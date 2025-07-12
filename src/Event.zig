const std = @import("std");

const WatchHandle = @import("Watcher.zig").WatchHandle;

pub const EventType = enum {
    create,
    modify,
    delete,
};

pub const EventMask = u32;

pub const EventMaskAll = EventMask(0xffffff);
pub const EventMaskCreate = EventMask(1 << 0);
pub const EventMaskModify = EventMask(1 << 1);
pub const EventMaskDelete = EventMask(1 << 2);

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
