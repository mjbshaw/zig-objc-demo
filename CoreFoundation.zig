pub const CFString = opaque {};
pub const CFStringRef = *CFString;

pub const CFRunLoop = opaque {};
pub const CFRunLoopRef = *CFRunLoop;

pub const CFTimeInterval = f64;
pub const CFRunLoopMode = CFStringRef;

pub const CFRunLoopRunResult = enum(i32) {
    finished = 1,
    stopped = 2,
    timed_out = 3,
    handled_source = 4,
    _,
};

pub const kCFRunLoopRunFinished = CFRunLoopRunResult.finished;
pub const kCFRunLoopRunStopped = CFRunLoopRunResult.stopped;
pub const kCFRunLoopRunTimedOut = CFRunLoopRunResult.timed_out;
pub const kCFRunLoopRunHandledSource = CFRunLoopRunResult.handled_source;

pub extern const kCFRunLoopCommonModes: CFRunLoopMode;
pub extern const kCFRunLoopDefaultMode: CFRunLoopMode;

pub extern fn CFRunLoopGetMain() CFRunLoopRef;

pub extern fn CFRunLoopRunInMode(mode: CFRunLoopMode, seconds: CFTimeInterval, return_after_source_handled: bool) CFRunLoopRunResult;
