const std = @import("std");
const objc = @import("objc");
const Foundation = @import("Foundation");

pub const UIApplication = opaque {
    pub const ZigInfo = objc.ExternClass("UIApplication");

    pub fn super(self: *UIApplication) *Foundation.NSObject {
        return @ptrCast(self);
    }

    /// `+[UIApplication sharedApplication]`
    pub fn sharedApplication() *UIApplication {
        return objc.msgSend(ZigInfo.objcClass(), "sharedApplication", *UIApplication, .{});
    }

    /// `-[UIApplication delegate]`
    pub fn delegate(self: *UIApplication) ?*UIApplicationDelegate {
        return objc.msgSend(self, "delegate", ?*UIApplicationDelegate, .{});
    }

    /// `-[UIApplication setDelegate:]`
    pub fn setDelegate(self: *UIApplication, delegate_object: ?*UIApplicationDelegate) void {
        objc.msgSend(self, "setDelegate:", void, .{delegate_object});
    }
};

pub const UIApplicationDelegate = opaque {};
