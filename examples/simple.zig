const std = @import("std");
const zw = @import("zigwatch");

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var watcher = try zw.Watcher.init(allocator);
    defer watcher.deinit();

    const wd = try watcher.add_watch(".", .{ .create = true, .delete = true });
    defer watcher.rm_watch(wd) catch {};
    var dir = try std.fs.cwd().openDir(".", .{});
    const fd = try dir.createFile("test.txt", .{});
    _ = try dir.deleteFile("test.txt");
    fd.close();
    dir.close();
    if (try watcher.poll(0)) |it| {
        var it_mut = it;
        while (try it_mut.next()) |event| {
            std.log.info("Got event: {} for handle: {} and path: {s}", .{ event.type, event.handle, event.path });
        }
    }
}
