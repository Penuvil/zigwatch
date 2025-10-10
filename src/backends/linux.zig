const std = @import("std");
const linux = std.os.linux;
const IN = linux.IN;

const EventFilter = @import("../Event.zig").EventFilter;
const EventType = @import("../Event.zig").EventType;
const Event = @import("../Event.zig").Event;
const WatchHandle = @import("../Watcher.zig").WatchHandle;
const WatchPath = @import("../Watcher.zig").WatchPath;

const FsEventError = @import("../Error.zig").FsEventError;

pub const mapInotifyEvent = [_]struct { mask: u32, event: EventType }{
    .{ .mask = IN.CREATE, .event = .Create },
    .{ .mask = IN.MODIFY, .event = .Modify },
    .{ .mask = IN.DELETE, .event = .Delete },
};

fn inotifyEventToEvent(mask: u32) !EventType {
    inline for (mapInotifyEvent) |entry| {
        if (mask == entry.mask) return entry.event;
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
    wfd: WatchHandle,
    poller: LinuxPoller,

    pub fn init() !Self {
        const fd = linux.inotify_init1(IN.NONBLOCK | IN.CLOEXEC);
        if (fd == -1) {
            return errnoToFsEventError(std.posix.errno(fd));
        }
        const poller = try LinuxPoller.init();
        _ = try poller.add(@intCast(fd));
        return Self{
            .wfd = @intCast(fd),
            .poller = poller,
        };
    }

    pub fn add_watch(self: *const Self, target: WatchPath, mask: EventFilter) !WatchHandle {
        const wd = linux.inotify_add_watch(@intCast(self.wfd), target.cstr(), mask.toBits());
        if (wd == -1) {
            return errnoToFsEventError(std.posix.errno(wd));
        }
        return @intCast(wd);
    }

    pub fn poll(self: *const Self) !usize {
        var buf: [20]linux.epoll_event = undefined;
        const count = try self.poller.wait(&buf, 0);
        std.log.debug("{}", .{count});
        for (buf[0..count]) |event| {
            if (event.data.fd == self.wfd) {
                var offset: usize = 0;
                var evbuf: [4096]u8 = undefined;
                const size = linux.read(@intCast(self.wfd), &evbuf, evbuf.len);
                while (offset < size) {
                    const e: *align(1) linux.inotify_event = @ptrCast(&evbuf[offset]);
                    const result: Event = .{
                        .handle = e.wd,
                        .type = try inotifyEventToEvent(e.mask),
                        .path = "",
                        .timestamp = 0,
                        .extra = null,
                    };
                    std.log.debug("{any}", .{result});
                    offset += @sizeOf(linux.inotify_event) + e.len;
                }
            }
        }
        return count;
    }

    pub fn deinit(self: *Self) void {
        self.poller.deinit();
        _ = linux.close(@intCast(self.wfd));
    }
};

pub const LinuxPoller = struct {
    const Self = @This();
    epfd: usize,

    pub fn init() !Self {
        const fd = linux.epoll_create1(linux.EPOLL.CLOEXEC);
        if (fd < 0) return errnoToFsEventError(fd);
        return Self{ .epfd = fd };
    }

    pub fn add(self: *const Self, fd: WatchHandle) !void {
        var event = linux.epoll_event{
            .events = linux.EPOLL.IN,
            .data = .{ .fd = @intCast(fd) },
        };
        const result = linux.epoll_ctl(@intCast(self.epfd), linux.EPOLL.CTL_ADD, @intCast(fd), &event);
        if (result < 0) return errnoToFsEventError(result);
    }

    pub fn wait(self: *const Self, events: []linux.epoll_event, timeout_ms: i32) !usize {
        const result = linux.epoll_wait(@intCast(self.epfd), events.ptr, @intCast(events.len), timeout_ms);
        if (result < 0) return errnoToFsEventError(result);
        return result;
    }

    pub fn deinit(self: *Self) void {
        _ = linux.close(@intCast(self.epfd));
    }
};
