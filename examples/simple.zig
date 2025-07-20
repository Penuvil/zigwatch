const std = @import("std");
const zw = @import("zigwatch");

pub fn main() void {
    const fd = zw.Watcher.init();
    // TODO: Add error handling
    defer _ = std.posix.close(@intCast(fd));

    _ = zw.Watcher.add_watch(fd, ".", zw.EventFilter.fromBits(zw.EventMaskModify));
    // TODO: Expand example as API matures
}
