pub const dispatch_queue_t = opaque {};

extern var _dispatch_main_q: dispatch_queue_t;
pub inline fn dispatch_get_main_queue() *dispatch_queue_t {
    return &_dispatch_main_q;
}

pub extern "c" fn dispatch_async_f(queue: *dispatch_queue_t, context: ?*anyopaque, work: fn () callconv(.C) void) void;
