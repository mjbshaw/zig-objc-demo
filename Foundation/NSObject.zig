const std = @import("std");
const objc = @import("objc");

pub const NSObject = opaque {
    pub const ZigInfo = objc.ExternClass("NSObject");

    /// `+[NSObject alloc]`
    pub fn alloc() *NSObject {
        return @ptrCast(objc.objc_alloc(ZigInfo.objcClass()));
    }

    /// `[[NSObject alloc] init]`
    pub fn allocInit() *NSObject {
        return @ptrCast(objc.objc_alloc_init(ZigInfo.objcClass()));
    }

    /// `-[NSObject init]`
    pub fn init(self: *NSObject) *NSObject {
        return objc.msgSend(self, "init", *NSObject, .{});
    }
};
