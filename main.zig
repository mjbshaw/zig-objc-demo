const std = @import("std");
const objc = @import("objc");
const builtin = @import("builtin");

const dispatch = @import("dispatch");
const CoreFoundation = @import("CoreFoundation");
const Foundation = @import("Foundation");
const UIKit = if (builtin.os.tag != .macos) @import("UIKit") else struct {};
const AppKit = if (builtin.os.tag == .macos) @import("AppKit") else struct {};

comptime {
    asm (
        \\    .section __DATA,__objc_imageinfo,regular,no_dead_strip
        \\L_OBJC_IMAGE_INFO:
        \\    .long 0
        \\    .long 64
    );
}

const AppDelegate = opaque {
    pub const ZigInfo = objc.ExternClass("AppDelegate");

    pub fn super(self: *AppDelegate) *Foundation.NSObject {
        return @ptrCast(self);
    }

    pub fn asNSApplicationDelegate(self: *AppDelegate) *AppKit.NSApplicationDelegate {
        return @ptrCast(self);
    }

    pub fn allocInit() *AppDelegate {
        return @ptrCast(objc.objc_alloc_init(ZigInfo.objcClass()));
    }

    pub fn setRunFunction(self: *AppDelegate, function: *const fn () callconv(.C) void) void {
        const method = @extern(*const fn (*AppDelegate, *const fn () callconv(.C) void) callconv(.C) void, .{ .name = "\x01-[AppDelegate setRunFunction:]" });
        method(self, function);
    }
};

fn runApp() callconv(.C) void {
    std.debug.print("Hello from the app's main run loop!\n", .{});

    while (true) {
        const mode = CoreFoundation.kCFRunLoopDefaultMode;
        const timeout_seconds = 1.0;
        switch (CoreFoundation.CFRunLoopRunInMode(mode, timeout_seconds, false)) {
            .finished => {
                std.debug.print("Run loop finished (weird, right?)\n", .{});
                return;
            },
            .stopped => {
                std.debug.print("Run loop was stopped (weird, right?)\n", .{});
                return;
            },
            .timed_out => {
                std.debug.print("Nothing to do...\n", .{});
            },
            .handled_source => continue,
            _ => |result| {
                std.debug.print("CFRunLoopRunInMode returned {}, which is weird and shouldn't happen.\n", .{result});
                return;
            },
        }
    }
}

fn initDelegate() callconv(.C) void {
    const app = UIKit.UIApplication.sharedApplication();
    const delegate: *AppDelegate = @ptrCast(app.delegate());
    std.debug.print("app: {*}  delegate: {*}\n", .{ app, delegate });
    delegate.setRunFunction(runApp);
}

pub fn main() u8 {
    const autoreleasepool = objc.objc_autoreleasePoolPush();
    defer objc.objc_autoreleasePoolPop(autoreleasepool);

    if (builtin.os.tag == .macos) {
        const app = AppKit.NSApplication.sharedApplication();
        const delegate = AppDelegate.allocInit();
        delegate.setRunFunction(runApp);
        app.setDelegate(delegate.asNSApplicationDelegate());
        app.run();
        return 0;
    } else {
        const main_queue = dispatch.dispatch_get_main_queue();
        dispatch.dispatch_async_f(main_queue, null, initDelegate);
        const delegate_class_name = Foundation.NSString.literalWithUniqueId("AppDelegate", "0");
        const argc: c_int = @bitCast(@as(c_uint, @truncate(std.os.argv.len)));
        const return_value = UIKit.UIApplicationMain(argc, @ptrCast(std.os.argv.ptr), null, delegate_class_name);
        return @intCast(return_value & 0xff);
    }
}
