const std = @import("std");
const linux = std.os.linux;
const IN = linux.IN;

const EventFilter = @import("../Event.zig").EventFilter;
const EventType = @import("../Event.zig").EventType;
const Event = @import("../Event.zig").Event;
const EventIterator = @import("../Watcher.zig").EventIterator;
const WatchHandle = @import("../Watcher.zig").WatchHandle;

const FsEventError = @import("../Error.zig").FsEventError;

const mapInotifyEvent = [_]struct { mask: u32, event: EventType }{
    .{ .mask = IN.CREATE, .event = .Create },
    .{ .mask = IN.MODIFY, .event = .Modify },
    .{ .mask = IN.DELETE, .event = .Delete },
};

fn eventFilterToBits(filter: EventFilter) u32 {
    var mask: u32 = 0;
    inline for (mapInotifyEvent) |map| {
        const include = switch (map.event) {
            .Create => filter.create,
            .Modify => filter.modify,
            .Delete => filter.delete,
        };
        if (include) mask |= map.mask;
    }
    return mask;
}

fn inotifyEventToEvent(mask: u32) !EventType {
    inline for (mapInotifyEvent) |entry| {
        if (mask & entry.mask != 0) return entry.event;
    }
    return FsEventError.Unexpected;
}

const mapFsEventError = [_]struct { posix: std.posix.E, err: FsEventError }{
    .{ .posix = .NOENT, .err = FsEventError.FileNotFound },
    .{ .posix = .PERM, .err = FsEventError.PermissionDenied },
    .{ .posix = .NOMEM, .err = FsEventError.OutOfMemory },
    .{ .posix = .INVAL, .err = FsEventError.InvalidArguments },
    .{ .posix = .MFILE, .err = FsEventError.TooManyOpenFiles },
    .{ .posix = .NFILE, .err = FsEventError.TooManyOpenFiles },
    .{ .posix = .NAMETOOLONG, .err = FsEventError.NameTooLong },
};

fn errnoToFsEventError(err: std.posix.E) FsEventError {
    inline for (mapFsEventError) |entry| {
        if (err == entry.posix) return entry.err;
    }
    return FsEventError.Unexpected;
}

pub const LinuxWatcher = struct {
    const Self = @This();
    const Handle = WatchHandle;

    wfd: Handle,
    poller: LinuxPoller,
    allocator: std.mem.Allocator,
    watches: std.AutoHashMap(Handle, []const u8),
    arena: std.heap.ArenaAllocator,
    evbuf: [16384]u8 align(8) = undefined,
    evbuf_size: usize = 0,
    event_queue: std.ArrayList(Event),

    pub fn init(allocator: std.mem.Allocator) !Self {
        const fd = linux.inotify_init1(IN.NONBLOCK | IN.CLOEXEC);
        if (fd < 0) {
            return errnoToFsEventError(std.posix.errno(fd));
        }

        errdefer _ = linux.close(fd);

        const poller = try LinuxPoller.init();
        errdefer poller.deinit();

        _ = try poller.add(fd);

        return Self{
            .wfd = @intCast(fd),
            .poller = poller,
            .allocator = allocator,
            .watches = std.AutoHashMap(Handle, []const u8).init(allocator),
            .arena = std.heap.ArenaAllocator.init(allocator),
            .event_queue = .{},
        };
    }

    pub fn add_watch(self: *Self, target: []const u8, filter: EventFilter) !WatchHandle {
        if (target.len + 1 > std.fs.max_path_bytes) {
            return error.NameTooLong;
        }
        var cstr_target_buf: [std.fs.max_path_bytes]u8 = undefined;
        @memcpy(cstr_target_buf[0..target.len], target);
        cstr_target_buf[target.len] = 0;
        const cstr_target: [*:0]const u8 = @ptrCast(&cstr_target_buf[0]);

        const mask = eventFilterToBits(filter);
        if (mask == 0) return FsEventError.InvalidArguments;
        const wd = linux.inotify_add_watch(@intCast(self.wfd), cstr_target, mask);
        if (wd < 0) {
            return errnoToFsEventError(std.posix.errno(wd));
        }
        const duped_target = try self.allocator.dupe(u8, target);
        errdefer self.allocator.free(duped_target);
        try self.watches.put(@intCast(wd), duped_target);
        return @intCast(wd);
    }

    pub fn rm_watch(self: *Self, handle: Handle) !void {
        const res = linux.inotify_rm_watch(@intCast(self.wfd), @intCast(handle));
        if (res < 0) {
            return errnoToFsEventError(std.posix.errno(res));
        }
        if (self.watches.fetchRemove(handle)) |entry| {
            self.allocator.free(entry.value);
        }
    }

    pub fn poll(self: *Self, timeout_ms: ?i32) !bool {
        _ = self.arena.reset(.retain_capacity);
        self.event_queue.clearRetainingCapacity();
        const allocator = self.arena.allocator();

        var buf: [20]linux.epoll_event = undefined;
        const count = try self.poller.wait(&buf, timeout_ms orelse -1);

        for (buf[0..count]) |event| {
            if (event.data.fd == self.wfd) {
                while (true) {
                    const result = linux.read(@intCast(self.wfd), &self.evbuf, self.evbuf.len);
                    const size: isize = @as(isize, @bitCast(result));
                    if (size < 0) {
                        const err = std.posix.errno(size);
                        if (err == .AGAIN) break;
                        return errnoToFsEventError(err);
                    }

                    if (size == 0) break;

                    var offset: usize = 0;
                    while (offset < size) {
                        const e: *linux.inotify_event = @ptrCast(@alignCast(&self.evbuf[offset]));
                        const e_length = @sizeOf(linux.inotify_event) + e.len;

                        const base_path = self.watches.get(e.wd) orelse {
                            offset += e_length;
                            continue;
                        };

                        const full_path = if (e.len > 0) blk: {
                            const name_ptr = e.getName().?;
                            break :blk try std.fs.path.join(allocator, &.{ base_path, name_ptr });
                        } else base_path;

                        try self.event_queue.append(self.allocator, .{
                            .handle = e.wd,
                            .type = try inotifyEventToEvent(e.mask),
                            .path = full_path,
                            .timestamp = 0,
                            .extra = null,
                        });

                        offset += e_length;
                    }
                }
            }
        }
        return self.event_queue.items.len > 0;
    }

    pub fn nextEvent(self: *Self, it: *EventIterator) !?Event {
        if (it.offset < self.event_queue.items.len) {
            defer it.offset += 1;
            return self.event_queue.items[it.offset];
        }
        return null;
    }

    pub fn deinit(self: *Self) void {
        var iter = self.watches.valueIterator();
        while (iter.next()) |v| {
            self.allocator.free(v.*);
        }
        self.event_queue.deinit(self.allocator);
        self.watches.deinit();
        self.arena.deinit();
        self.poller.deinit();
        _ = linux.close(@intCast(self.wfd));
    }
};

pub const LinuxPoller = struct {
    const Self = @This();
    epfd: i32,

    pub fn init() !Self {
        const fd = linux.epoll_create1(linux.EPOLL.CLOEXEC);
        if (fd < 0) return errnoToFsEventError(std.posix.errno(fd));
        return Self{ .epfd = @intCast(fd) };
    }

    pub fn add(self: *const Self, fd: usize) !void {
        var event = linux.epoll_event{
            .events = linux.EPOLL.IN,
            .data = .{ .fd = @intCast(fd) },
        };
        const result = linux.epoll_ctl(self.epfd, linux.EPOLL.CTL_ADD, @intCast(fd), &event);
        if (result < 0) return errnoToFsEventError(std.posix.errno(result));
    }

    pub fn wait(self: *const Self, events: []linux.epoll_event, timeout_ms: i32) !usize {
        const result = linux.epoll_wait(self.epfd, events.ptr, @intCast(events.len), timeout_ms);
        if (result < 0) return errnoToFsEventError(std.posix.errno(result));
        return result;
    }

    pub fn deinit(self: *Self) void {
        _ = linux.close(self.epfd);
    }
};
