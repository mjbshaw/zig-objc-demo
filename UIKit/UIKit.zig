const Foundation = @import("Foundation");

pub const UIApplication = @import("UIApplication.zig").UIApplication;
pub const UIApplicationDelegate = @import("UIApplication.zig").UIApplicationDelegate;

extern "c" fn UIApplicationMain(argc: c_int, argv: *?*c_char, principal_class_name: ?*Foundation.NSString, delegate_class_name: ?*Foundation.NSString) c_int;
