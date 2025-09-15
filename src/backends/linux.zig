const std = @import("std");

const EventFilter = @import("../Event.zig").EventFilter;
const EventType = @import("../Event.zig").EventType;
const WatchHandle = @import("../Watcher.zig").WatchHandle;
const WatchPath = @import("../Watcher.zig").WatchPath;
const inotify = @cImport({
    @cInclude("sys/inotify.h");
});

const FsEventError = @import("../Error.zig").FsEventError;

const IN_ACCESS = inotify.IN_ACCESS;
const IN_ATTRIB = inotify.IN_ATTRIB;
const IN_CLOSE_WRITE = inotify.IN_CLOSE_WRITE;
const IN_CLOSE_NOWRITE = inotify.IN_CLOSE_NOWRITE;
const IN_CLOSE = inotify.IN_CLOSE;
const IN_CREATE = inotify.IN_CREATE;
const IN_DELETE = inotify.IN_DELETE;
const IN_DELETE_SELF = inotify.IN_DELETE_SELF;
const IN_MODIFY = inotify.IN_MODIFY;
const IN_MOVE_SELF = inotify.IN_MOVE_SELF;
const IN_MOVED_FROM = inotify.IN_MOVED_FROM;
const IN_MOVED_TO = inotify.IN_MOVED_TO;
const IN_MOVE = inotify.IN_MOVE;
const IN_OPEN = inotify.IN_OPEN;

pub const mapInotify = [_]struct { mask: u32, event: EventType }{
    .{ .mask = IN_CREATE, .event = .Create },
    .{ .mask = IN_MODIFY, .event = .Modify },
    .{ .mask = IN_DELETE, .event = .Delete },
};

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
    pub fn init() !WatchHandle {
        const fd = inotify.inotify_init();
        if (fd == -1) {
            return errnoToFsEventError(std.posix.errno(fd));
        }
        return @intCast(fd);
    }

    pub fn add_watch(fd: WatchHandle, target: WatchPath, mask: EventFilter) !WatchHandle {
        const wd = inotify.inotify_add_watch(@intCast(fd), target.cstr(), mask.toBits());
        if (wd == -1) {
            return errnoToFsEventError(std.posix.errno(wd));
        }
        return @intCast(wd);
    }
};
