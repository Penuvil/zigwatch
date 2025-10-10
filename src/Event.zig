const std = @import("std");
const builtin = @import("builtin");

const WatchHandle = @import("Watcher.zig").WatchHandle;

pub const mapPlatform = switch (builtin.os.tag) {
    .linux => @import("backends/linux.zig").mapInotifyEvent,
    else => @compileError("Unsupported OS"),
};

pub const EventType = enum {
    Create,
    Modify,
    Delete,
};

pub const EventFilter = struct {
    create: bool = false,
    modify: bool = false,
    delete: bool = false,

    pub fn toBits(self: EventFilter) u32 {
        var mask: u32 = 0;
        inline for (mapPlatform) |map| {
            const include = switch (map.event) {
                .Create => self.create,
                .Modify => self.modify,
                .Delete => self.delete,
            };
            if (include) mask |= map.mask;
        }
        std.log.debug("{}", .{mask});
        return mask;
    }
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
