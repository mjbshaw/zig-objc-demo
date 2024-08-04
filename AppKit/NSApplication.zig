const std = @import("std");
const objc = @import("objc");
const Foundation = @import("Foundation");

pub const NSApplication = opaque {
    pub const ZigInfo = objc.ExternClass("NSApplication");

    pub fn super(self: *NSApplication) *Foundation.NSObject {
        return @ptrCast(self);
    }

    /// `+[NSApplication sharedApplication]`
    pub fn sharedApplication() *NSApplication {
        return objc.msgSend(ZigInfo.objcClass(), "sharedApplication", *NSApplication, .{});
    }

    /// `-[NSApplication run]`
    pub fn run(self: *NSApplication) void {
        objc.msgSend(self, "run", void, .{});
    }

    /// `-[NSApplication stop:]`
    pub fn stop(self: *NSApplication, sender: *objc.id) void {
        objc.msgSend(self, "stop:", void, .{sender});
    }

    /// `-[NSApplication delegate]`
    pub fn delegate(self: *NSApplication) ?*NSApplicationDelegate {
        return objc.msgSend(self, "delegate", ?*NSApplicationDelegate, .{});
    }

    /// `-[NSApplication setDelegate:]`
    pub fn setDelegate(self: *NSApplication, delegate_object: ?*NSApplicationDelegate) void {
        return objc.msgSend(self, "setDelegate:", void, .{delegate_object});
    }
};

pub const NSApplicationDelegate = opaque {};
