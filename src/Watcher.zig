const std = @import("std");
const builtin = @import("builtin");

pub const Watcher = switch (builtin.os.tag) {
    .linux => @import("backends/linux.zig").LinuxWatcher,
    else => @compileError("Unsupported OS"),
};

pub const WatchHandle = usize;
