const std = @import("std");

const EventFilter = @import("../Event.zig").EventFilter;
const WatchHandle = @import("../Watcher.zig").WatchHandle;
const inotify = @cImport({
    @cInclude("sys/inotify.h");
});

pub const LinuxWatcher = struct {
    pub fn init() WatchHandle {
        const fd = inotify.inotify_init();
        // TODO: Return error on failed init
        return @intCast(fd);
    }

    pub fn add_watch(fd: WatchHandle, pathname: [:0]const u8, mask: EventFilter) WatchHandle {
        const wd = inotify.inotify_add_watch(@intCast(fd), pathname, mask.toBits());
        // TODO: Return error on failure
        return @intCast(wd);
    }
};

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
