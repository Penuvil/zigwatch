const std = @import("std");
const builtin = @import("builtin");
const Event = @import("Event.zig").Event;
const EventFilter = @import("Event.zig").EventFilter;

pub const Backend = switch (builtin.os.tag) {
    .linux => @import("backends/linux.zig").LinuxWatcher,
    else => @compileError("Unsupported OS"),
};

pub const Watcher = union(enum) {
    backend: Backend,

    pub fn init(allocator: std.mem.Allocator) !Watcher {
        const backend = try Backend.init(allocator);
        return .{
            .backend = backend,
        };
    }

    pub fn add_watch(self: *Watcher, path: []const u8, mask: EventFilter) !WatchHandle {
        return self.backend.add_watch(path, mask);
    }

    pub fn rm_watch(self: *Watcher, handle: WatchHandle) !void {
        return self.backend.rm_watch(handle);
    }

    pub fn poll(self: *Watcher, timeout_ms: ?i32) !?EventIterator {
        if (try self.backend.poll(timeout_ms)) {
            return EventIterator{ .watcher = self };
        } else {
            return null;
        }
    }

    fn nextEvent(self: *Watcher, it: *EventIterator) !?Event {
        return self.backend.nextEvent(it);
    }

    pub fn deinit(self: *Watcher) void {
        self.backend.deinit();
    }
};

pub const EventIterator = struct {
    const Self = @This();
    watcher: *Watcher,
    offset: usize = 0,

    pub fn next(self: *Self) !?Event {
        return self.watcher.nextEvent(self);
    }
};

pub const WatchHandle = isize;
