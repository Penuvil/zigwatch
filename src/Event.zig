const std = @import("std");

const WatchHandle = @import("Watcher.zig").WatchHandle;

pub const EventMask = enum(u32) {
    Create = 1 << 0,
    Modify = 1 << 1,
    Delete = 1 << 2,
};

pub const EventFilterMask = struct {
    create: bool = true,
    modify: bool = true,
    delete: bool = true,

    pub fn fromBits(bits: EventMask) EventFilterMask {
        return EventFilterMask{
            .create = bits == EventMask.Create,
            .modify = bits == EventMask.Modify,
            .delete = bits == EventMask.Delete,
        };
    }

    pub fn toBits(self: EventFilterMask) u32 {
        var result: u32 = 0;
        if (self.create) result |= @intFromEnum(EventMask.Create);
        if (self.modify) result |= @intFromEnum(EventMask.Modify);
        if (self.delete) result |= @intFromEnum(EventMask.Delete);
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
