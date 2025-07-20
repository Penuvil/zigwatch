const std = @import("std");

const WatchHandle = @import("Watcher.zig").WatchHandle;

pub const EventType = enum {
    Create,
    Modify,
    Delete,
};

pub const EventMask = u32;

pub const EventMaskCreate = 1 << 0;
pub const EventMaskModify = 1 << 1;
pub const EventMaskDelete = 1 << 2;
pub const EventMaskAll = 0xFFFFFFFF;

pub const EventFilter = struct {
    create: bool = true,
    modify: bool = true,
    delete: bool = true,

    pub fn fromBits(bits: EventMask) EventFilter {
        return EventFilter{
            .create = (bits & EventMaskCreate) != 0,
            .modify = (bits & EventMaskModify) != 0,
            .delete = (bits & EventMaskDelete) != 0,
        };
    }

    pub fn toBits(self: EventFilter) u32 {
        var result: u32 = 0;
        if (self.create) result |= EventMaskCreate;
        if (self.modify) result |= EventMaskModify;
        if (self.delete) result |= EventMaskDelete;
        return result;
    }
};

pub const Event = struct {
    handle: WatchHandle,
    type: EventMask,
    path: []const u8,
    timestamp: i64,
    extra: ?EventExtra,
};

pub const EventExtra = union {
    cookie: u32,
    flags: u64,
    reserved: void,
};
