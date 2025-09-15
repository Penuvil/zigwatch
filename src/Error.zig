pub const FsEventError = error{
    FileNotFound,
    PermissionDenied,
    OutOfMemory,
    InvalidArguments,
    TooManyOpenFiles,
    NameTooLong,
    Unexpected,
};
