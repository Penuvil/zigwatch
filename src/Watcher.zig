const std = @import("std");
const builtin = @import("builtin");

pub const WatchPath = struct {
    const Self = @This();
    buffer: [256]u8 = undefined,
    len: usize = 0,
    fallback: ?[]const u8 = null,

    pub fn init(target: []const u8, allocator: std.mem.Allocator) !Self {
        var result = Self{};

        if (target.len < result.buffer.len) {
            @memcpy(result.buffer[0..target.len], target);
            result.buffer[target.len] = 0;
            result.len = target.len;
        } else {
            result.fallback = try allocator.dupeZ(u8, target);
        }

        return result;
    }

    pub fn path(self: *const Self) []const u8 {
        if (self.fallback) |fb| return std.mem.sliceTo(fb, 0);
        return self.buffer[0..self.len];
    }

    pub fn cstr(self: *const Self) [*:0]const u8 {
        if (self.fallback) |fb| return fb[0..fb.len :0].ptr;
        return self.buffer[0..self.len :0].ptr;
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
