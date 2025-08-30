const std = @import("std");
const builtin = @import("builtin");

pub const WatchPath = struct {
    const Self = @This();
    buffer: std.BoundedArray(u8, 256),
    fallback: ?[]const u8 = null,

    pub fn init(target: []const u8, allocator: std.mem.Allocator) !Self {
        var result = Self{ .buffer = .{} };

        if (target.len < result.buffer.capacity()) {
            try result.buffer.appendSlice(target);
        } else {
            result.fallback = try allocator.dupe(u8, target);
        }

        return result;
    }

    pub fn path(self: *const Self) []const u8 {
        return self.fallback orelse self.buffer.slice();
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        if (self.fallback) |fb| allocator.free(fb);
    }
};

pub const WatchConfig = struct {
    path: WatchPath,
    timeout: u32,
    debounce: u3,
};

pub const Watcher = switch (builtin.os.tag) {
    .linux => @import("backends/linux.zig").LinuxWatcher,
    else => @compileError("Unsupported OS"),
};

pub const WatchHandle = isize;
