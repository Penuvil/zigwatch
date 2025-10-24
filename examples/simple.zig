const std = @import("std");
const zw = @import("zigwatch");

pub fn main() !void {
    var watcher = try zw.Watcher.init();
    // TODO: Add error handling
    std.log.info("Watcher created: {}", .{watcher.wfd});
    defer watcher.deinit();
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var target = try zw.WatchPath.init(".", allocator);
    defer _ = target.deinit(allocator);
    const wd = try watcher.add_watch(target, .{ .create = true, .delete = true });
    std.log.info("Watch added: {}", .{wd});
    // TODO: Expand example as API matures
    var dir = try std.fs.Dir.openDir(std.fs.cwd(), target.path(), .{});
    const fd = try dir.createFile("test.txt", .{});
    _ = try dir.deleteFile("test.txt");
    defer _ = std.fs.File.close(fd);
    defer dir.close();
    _ = try watcher.poll();
}
