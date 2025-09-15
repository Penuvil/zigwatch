const std = @import("std");
const zw = @import("zigwatch");

pub fn main() !void {
    const fd = try zw.Watcher.init();
    // TODO: Add error handling
    std.log.info("Watcher created: {}", .{fd});
    defer _ = std.posix.close(@intCast(fd));
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var target = try zw.WatchPath.init(".", allocator);
    defer _ = target.deinit(allocator);
    const wd = try zw.Watcher.add_watch(fd, target, .{ .modify = true });
    std.log.info("Watch added: {}", .{wd});
    // TODO: Expand example as API matures
}
