const std = @import("std");
const builtin = @import("builtin");
// pub const appkit = @import("appkit/appkit.zig");

// libobjc.dylib
extern "c" fn objc_autoreleasePoolPush() *void;
extern "c" fn objc_autoreleasePoolPop(*void) void;

extern "c" fn objc_alloc(class: *Class) ?*id; // Same as [Class alloc].
extern "c" fn objc_alloc_init(class: *Class) ?*id; // Same as [[Class alloc] init].
extern "c" fn objc_opt_new(class: *Class) ?*id; // Same as [Class new].

// libobjc.dylib
extern "c" fn objc_getClass(name: [*:0]const c_char) *Class;
extern "c" fn objc_getProtocol(name: [*:0]const c_char) *Protocol;
extern "c" fn class_addProtocol(class: ?*Class, protocol: *Protocol) BOOL;
extern "c" fn objc_allocateClassPair(superclass: ?*Class, name: [*:0]const c_char, extra_bytes: usize) ?*Class;
extern "c" fn class_addMethod(class: ?*Class, name: SEL, imp: *const anyopaque, types: ?[*:0]const c_char) BOOL;

const SEL = [*:0]const c_char;
const BOOL = u8;

// 	.section	__DATA,__objc_imageinfo,regular,no_dead_strip
// L_OBJC_IMAGE_INFO:
// 	.long	0
// 	.long	64

// const objc_image_info: [2]u32 = .{0, 64};
comptime {
    // @export(objc_image_info, .{ .name = "\x01L_OBJC_IMAGE_INFO", .section = "__DATA,__objc_imageinfo,regular,no_dead_strip" });
    // asm (
    //     \\    .section __DATA,__objc_imageinfo,regular,no_dead_strip
    //     \\L_OBJC_IMAGE_INFO:
    //     \\    .long 0
    //     \\    .long 64
    // );
}

pub const AvailabilityPlatforms = struct {
    macos: std.SemanticVersion = .{ 0, 0, 0 },
    ios: std.SemanticVersion = .{ 0, 0, 0 },
    tvos: std.SemanticVersion = .{ 0, 0, 0 },
    watchos: std.SemanticVersion = .{ 0, 0, 0 },
    driverkit: std.SemanticVersion = .{ 0, 0, 0 },
    visionos: std.SemanticVersion = .{ 0, 0, 0 },
};

// This requires CoreFoundation to be linked on macOS 10.14 and below, iOS/tvOS 12 and below, or watchOS 5 and below. I'm not going to worry about that, though.
extern "c" fn __isPlatformVersionAtLeast(platform: u32, major: u32, minor: u32, patch: u32) i32;

// This is generally equivalent to @available(...).
pub inline fn available(platforms: AvailabilityPlatforms) bool {
    const query = comptime switch (builtin.target.os.tag) {
        .macos => .{ 1, platforms.macos },
        .ios => .{ 2, platforms.ios },
        .tvos => .{ 3, platforms.tvos },
        .watchos => .{ 4, platforms.watchos },
        .driverkit => .{ 10, platforms.driverkit },
        .visionos => .{ 11, platforms.visionos },
        else => @compileError("Unsupported target platform"),
    };

    const target_min = comptime switch (builtin.target.os.version_range.getVersionRange()) {
        .none => .{ .major = 0, .minor = 0, .patch = 0 },
        .semver => |ver| ver.min,
        else => @compileError("Unsupported target platform"),
    };
    if (comptime target_min.order(query[1]).compare(.gte)) {
        return true;
    }

    // Fun fact, Android uses int32_t __isOSVersionAtLeast(int32_t Major, int32_t Minor, int32_t Subminor).
    return __isPlatformVersionAtLeast(query[0], query[1].major, query[1].minor, query[1].patch) != 0;
}

// iOS 2.0+ iPadOS 2.0+ Mac Catalyst 13.0+ tvOS 9.0+ visionOS 1.0+
// UIKit
extern "c" fn UIApplicationMain(argc: c_int, argv: [*][*:0]c_char, class_name: *void, delegate_class_name: *void) c_int;
// int UIApplicationMain(int argc, char * _Nullable *argv, NSString *principalClassName, NSString *delegateClassName);

// AppKit

// macOS explicitly ignores its parameters and gets them from `_NSGetArgv` and `_NSGetArgc`.
// int NSApplicationMain(int argc, const char * _Nonnull *argv);
// extern "c" fn NSApplicationMain(argc: c_int, argv: ?[*][*:0]c_char) c_int;

const selectors = .{};

const id = opaque {};
// const Class = packed struct { base: id };
// const Protocol = packed struct { base: id };
const Class = id;
const Protocol = id;

fn ExternClass(name: anytype) type {
    return struct {
        comptime {
            // zig fmt: off
            asm (
                "    .section __DATA,__objc_classrefs,regular,no_dead_strip\n" ++
                "    .p2align 3, 0x0\n" ++
                "_OBJC_CLASSLIST_REFERENCES_$_" ++ name ++ ":\n" ++
                "    .quad _OBJC_CLASS_$_" ++ name
            );
            // zig fmt: on
        }

        pub fn objcClass() *Class {
            var ptr: *anyopaque = undefined;
            if (comptime builtin.cpu.arch == .x86_64) {
                // zig fmt: off
                asm (
                    "movq _OBJC_CLASSLIST_REFERENCES_$_" ++ name ++ "(%rip), %[ptr]"
                    : [ptr] "=r" (ptr),
                );
                // zig fmt: on
            } else {
                // zig fmt: off
                asm (
                    "adrp %[ptr], _OBJC_CLASSLIST_REFERENCES_$_" ++ name ++ "@PAGE\n" ++
                    "ldr %[ptr], [%[ptr], _OBJC_CLASSLIST_REFERENCES_$_" ++ name ++ "@PAGEOFF]"
                    : [ptr] "=r" (ptr),
                );
                // zig fmt: on
            }
            return @ptrCast(ptr);
        }
    };
}

// Protocols are super annoying to do at compile/link time because you have to weakly link the full definition. So this just does it at runtime.
fn MakeProtocol(name: anytype) type {
    return struct {
        var protocol_ptr: ?*Protocol = null;
        pub fn objcProtocol() *Protocol {
            var ptr = @atomicLoad(?*Protocol, &protocol_ptr, .unordered);
            if (ptr == null) {
                ptr = objc_getProtocol(@ptrCast(name));
                std.debug.print("ptr: {?}\n", .{ptr});
                @atomicStore(?*Protocol, &protocol_ptr, ptr, .unordered);
            }
            return @ptrCast(ptr);
        }
    };
}

fn makeCallingConventionC(fn_type: type) type {
    return @Type(.{ .Fn = .{
        .calling_convention = .C,
        .is_generic = false,
        .is_var_args = false,
        .return_type = @typeInfo(fn_type).Fn.return_type,
        .params = @typeInfo(fn_type).Fn.params,
    } });
}

// fn makeMsgSend(comptime selector: anytype, fn_type: type) *makeCallingConventionC(fn_type) {
//     const objc_msgSend = @extern(makeCallingConventionC(fn_type), .{ .name = "objc_msgSend$" ++ selector });
//     return @ptrCast(objc_msgSend);
// }

const NSObject = opaque {
    // base: id = .{},

    pub const ZigInfo = ExternClass("NSObject");

    pub fn alloc() *NSObject {
        return @ptrCast(objc_alloc(ZigInfo.objcClass()));
    }

    pub fn alloc_init() *NSObject {
        return @ptrCast(objc_alloc_init(ZigInfo.objcClass()));
    }

    extern "c" fn @"objc_msgSend$init"(*NSObject) *NSObject;
    pub fn init(self: *NSObject) *NSObject {
        return @"objc_msgSend$init"(self);
    }
};

// TODO: use CFString APIs for some operations
const NSString = opaque {
    pub fn super(self: *NSString) *NSObject {
        return @ptrCast(self);
    }

    pub const ZigInfo = ExternClass("NSString");

    pub fn alloc() *NSString {
        return @ptrCast(objc_alloc(ZigInfo.objcClass()));
    }

    pub fn alloc_init() *NSString {
        return @ptrCast(objc_alloc_init(ZigInfo.objcClass()));
    }

    extern "c" fn @"objc_msgSend$init"(*NSString) *NSString;
    pub fn init(self: *NSString) *NSString {
        return @"objc_msgSend$init"(self);
    }
};

const NSApplication = packed struct {
    pub fn super(self: *NSApplication) *NSObject {
        return @ptrCast(self);
    }

    pub const ZigInfo = ExternClass("NSApplication");

    extern "c" fn @"objc_msgSend$sharedApplication"(*Class) *NSApplication;
    pub fn sharedApplication() *NSApplication {
        // const msg_send = makeMsgSend("sharedApplication", fn (*Class) *NSApplication);
        // return msg_send(ZigInfo.objcClass());
        return @"objc_msgSend$sharedApplication"(ZigInfo.objcClass());
    }

    extern "c" fn @"objc_msgSend$run"(*NSApplication) void;
    pub fn run(self: *NSApplication) void {
        @"objc_msgSend$run"(self);
    }

    extern "c" fn @"objc_msgSend$stop:"(*NSApplication, *id) void;
    pub fn stop(self: *NSApplication, sender: *id) void {
        @"objc_msgSend$stop:"(self, sender);
    }

    extern "c" fn @"objc_msgSend$delegate"(*NSApplication) ?*NSApplicationDelegate;
    pub fn delegate(self: *NSApplication) ?*NSApplicationDelegate {
        return @"objc_msgSend$delegate"(self);
    }

    extern "c" fn @"objc_msgSend$setDelegate:"(*NSApplication, ?*NSApplicationDelegate) void;
    pub fn setDelegate(self: *NSApplication, delegate_object: ?*NSApplicationDelegate) void {
        return @"objc_msgSend$setDelegate:"(self, delegate_object);
    }
};

const NSNotification = packed struct {
    pub const ZigInfo = ExternClass("NSNotification");

    pub fn super(self: *NSNotification) *NSObject {
        return @ptrCast(self);
    }

    extern "c" fn @"objc_msgSend$name"(*NSNotification) *NSString;
    pub fn name(self: *NSNotification) *NSString {
        return @"objc_msgSend$name"(self);
    }

    extern "c" fn @"objc_msgSend$object"(*NSNotification) ?*id;
    pub fn object(self: *NSNotification) ?*id {
        // const msg_send = makeMsgSend("object", fn (*NSNotification) ?*id);
        // return msg_send(self);
        return @"objc_msgSend$object"(self);
    }
};

const NSApplicationDelegate = opaque {
    const ZigInfo = MakeProtocol("NSApplicationDelegate");
};

const MachApp = packed struct {
    pub const ZigInfo = ExternClass("MachApp");

    pub fn super(self: *MachApp) *NSObject {
        return @ptrCast(self);
    }

    pub fn asNSApplicationDelegate(self: *MachApp) *NSApplicationDelegate {
        return @ptrCast(self);
    }

    pub fn setRunFunction(self: *MachApp, function: fn () callconv(.C) void) void {
        const method = @extern(fn (*MachApp, fn () callconv(.C) void) callconv(.C) void, .{ .name = "-[MachApp setRunFunction:" });
        method(self, function);
    }

    pub fn alloc_init() *MachApp {
        return @ptrCast(objc_alloc_init(ZigInfo.objcClass()));
    }
};

fn mainRunLoop() callconv(.C) void {}

pub fn main() u8 {
    const autoreleasepool = objc_autoreleasePoolPush();
    defer objc_autoreleasePoolPop(autoreleasepool);

    var return_value: c_int = undefined;
    if (comptime builtin.target.os.tag == .macos) {
        // return_value = NSApplicationMain(0, null);
        return_value = 0;
    } else {
        return_value = UIApplicationMain(std.os.argv.len, std.os.argv.ptr, null, null);
    }

    // var x: NSApplication = .{ .base = .{ .base = .{ .ptr = &return_value } } };
    // const y: NSString = .{ .base = .{ .base = .{ .ptr = &return_value } } };
    // x = y;

    // return_value = @bitCast(@as(u32, @truncate(@intFromPtr(NSObject.ZigInfo.objcClass().base.ptr))));

    std.debug.print("{}\n", .{NSObject.ZigInfo.objcClass()});
    std.debug.print("{}\n", .{NSString.ZigInfo.objcClass()});
    std.debug.print("{}\n", .{NSApplication.ZigInfo.objcClass()});

    const obj = NSObject.alloc().init();
    std.debug.print("{}\n", .{obj});

    const str = NSString.alloc_init();
    std.debug.print("{}\n", .{str});

    const app = NSApplication.sharedApplication();
    std.debug.print("{}\n", .{app});

    const delegate = MachApp.alloc_init();
    delegate.setRunFunction(mainRunLoop);
    app.setDelegate(delegate.asNSApplicationDelegate());

    app.run();

    return @truncate(@as(u32, @bitCast(return_value)));
}

// 4567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890
// Currently we only target:
//
//   - macOS 12+
//   - iOS 15+
//   - tvOS 15+
//   - visionOS 1+
//   - watchOS 8+
//
// Except watchOS isn't actually supported because it doesn't support UIKit or AppKit. Support could
// be added if someone is motivated enough.
//
// We probably won't need all of the following commands. Realistically we only need 4: iOS
// arm64/x86_64 and macOS arm64/x86_64. The generated assembly code is (generally) the same across
// all the platforms. The only reason iOS and macOS require separate assembly blobs is because they
// use different APIs (UIKit vs AppKit).
//
// To generate updated assembly, run the "iOS arm64 device," "iOS x86_64 simulator," "macOS arm64,"
// and "macOS x86_64" commands. Then run the following chain of `sed` commands on each assembly
// file to clean up the asm (replace nonprintable characters with hex escape sequences, convert
// tabs to spaces, remove compiler-generated comments, remove `.build_version`, and add `\\` to turn
// them into Zig strings):
//
// sed 's/\x01/\\x01/g' | sed 's/\t/    /g' | sed -E 's/ +; .*//g' | sed -E 's/([^ ])    /\1 /g' | sed -E '/^    \.build_version .*/d' | sed -E '/^;.*/d' | sed -E 's/^/\\\\/'
//
// Below are all of the following commands that could be used for generating the assembly:
//
// iOS arm64 device: cc -c file.m -o arm64-apple-ios15.s -target arm64-apple-ios15 -S -Os -fomit-frame-pointer -fobjc-arc -fno-objc-exceptions -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk
// iOS arm64 simulator: cc -c file.m -o arm64-apple-ios15-sim.s -target arm64-apple-ios15 -S -Os -fomit-frame-pointer -fobjc-arc -fno-objc-exceptions -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator.sdk
// iOS x86_64 simulator: cc -c file.m -o x86_64-apple-ios15-sim.s -target x86_64-apple-ios15 -S -Os -fomit-frame-pointer -fobjc-arc -fno-objc-exceptions -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator.sdk
//
// macOS arm64: cc -c file.m -o arm64-apple-macos12.s -target arm64-apple-macos12 -S -Os -fomit-frame-pointer -fobjc-arc -fno-objc-exceptions -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk
// macOS x86_64: cc -c file.m -o x86_64-apple-macos12.s -target x86_64-apple-macos12 -S -Os -fomit-frame-pointer -fobjc-arc -fno-objc-exceptions -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk
//
// Mac Catalyst arm64: cc -c file.m -o arm64-apple-ios15-macabi.s -target arm64-apple-ios15-macabi -S -Os -fomit-frame-pointer -fobjc-arc -fno-objc-exceptions -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk -iframework /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/System/iOSSupport/System/Library/Frameworks
// Mac Catalyst x86_64: cc -c file.m -o x86_64-apple-ios15-macabi.s -target x86_64-apple-ios15-macabi -S -Os -fomit-frame-pointer -fobjc-arc -fno-objc-exceptions -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk -iframework /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/System/iOSSupport/System/Library/Frameworks
//
// visionOS arm64 device: cc -c file.m -o arm64-apple-xros12.s -target arm64-apple-xros12 -S -Os -fomit-frame-pointer -fobjc-arc -fno-objc-exceptions -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/XROS.platform/Developer/SDKs/XROS.sdk
// visionOS arm64 simulator: cc -c file.m -o arm64-apple-xros12-sim.s -target arm64-apple-xros12 -S -Os -fomit-frame-pointer -fobjc-arc -fno-objc-exceptions -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/XRSimulator.platform/Developer/SDKs/XRSimulator.sdk
//
// watchOS arm64 device: cc -c file.m -o arm64-apple-watchos8.s -target arm64-apple-watchos8 -S -Os -fomit-frame-pointer -fobjc-arc -fno-objc-exceptions -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/WatchOS.platform/Developer/SDKs/WatchOS.sdk
// watchOS arm64 simulator: cc -c file.m -o arm64-apple-watchos8-sim.s -target arm64-apple-watchos8 -S -Os -fomit-frame-pointer -fobjc-arc -fno-objc-exceptions -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/WatchSimulator.platform/Developer/SDKs/WatchSimulator.sdk
// watchOS x86_64 simulator: cc -c file.m -o x86_64-apple-watchos8-sim.s -target x86_64-apple-watchos8 -S -Os -fomit-frame-pointer -fobjc-arc -fno-objc-exceptions -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/WatchSimulator.platform/Developer/SDKs/WatchSimulator.sdk
//
// tvOS arm64 device: cc -c file.m -o arm64-apple-tvos15.s -target arm64-apple-tvos15 -S -Os -fomit-frame-pointer -fobjc-arc -fno-objc-exceptions -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/AppleTVOS.platform/Developer/SDKs/AppleTVOS.sdk
// tvOS arm64 simulator: cc -c file.m -o arm64-apple-tvos15-sim.s -target arm64-apple-tvos15 -S -Os -fomit-frame-pointer -fobjc-arc -fno-objc-exceptions -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/AppleTVSimulator.platform/Developer/SDKs/AppleTVSimulator.sdk
// tvOS x86_64 simulator: cc -c file.m -o x86_64-apple-tvos15-sim.s -target x86_64-apple-tvos15 -S -Os -fomit-frame-pointer -fobjc-arc -fno-objc-exceptions -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/AppleTVSimulator.platform/Developer/SDKs/AppleTVSimulator.sdk
//
// The following is a script that will do everything for you:
//
// #!/bin/zsh
// cc -c file.m -o arm64-apple-ios15.s -target arm64-apple-ios15 -S -Os -fomit-frame-pointer -fobjc-arc -fno-objc-exceptions -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk
// cc -c file.m -o x86_64-apple-ios15-sim.s -target x86_64-apple-ios15 -S -Os -fomit-frame-pointer -fobjc-arc -fno-objc-exceptions -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator.sdk
// cc -c file.m -o arm64-apple-macos12.s -target arm64-apple-macos12 -S -Os -fomit-frame-pointer -fobjc-arc -fno-objc-exceptions -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk
// cc -c file.m -o x86_64-apple-macos12.s -target x86_64-apple-macos12 -S -Os -fomit-frame-pointer -fobjc-arc -fno-objc-exceptions -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk
// for file in arm64-apple-ios15.s x86_64-apple-ios15-sim.s arm64-apple-macos12.s x86_64-apple-macos12.s
// do
//   < "$file" sed 's/\x01/\\x01/g' | sed 's/\t/    /g' | sed 's/  *; .*//g' | sed 's/  *## .*//g' | sed 's/\([^ ]\)    /\1 /g' | sed '/^    \.build_version .*/d' | sed '/^; .*/d' | sed '/^## .*/d' | sed 's/^/\\\\/' >! "$file"
// done
//
// Next, just copy and paste the contents of the assembly files into the relevant locations in this
// *.zig file.
//
// This is the Objective-C code. Save it to a file named "file.m" before running those commands.
//
// #import <Foundation/Foundation.h>
// #if __has_include(<UIKit/UIKit.h>)
// #import <UIKit/UIKit.h>
// #else
// #import <AppKit/AppKit.h>
// #endif

// @interface MachApp : NSObject
// @end

// #if __has_include(<UIKit/UIKit.h>)
// @interface MachApp () <UIApplicationDelegate>
// #else
// @interface MachApp () <NSApplicationDelegate>
// #endif
// @end

// @implementation MachApp {
//     void (*_runFunction)(void);
// }

// - (void)setRunFunction:(void(*)(void))runFunction __attribute__((objc_direct)) {
//     _runFunction = runFunction;
// }

// #if __has_include(<UIKit/UIKit.h>)
// - (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary<UIApplicationLaunchOptionsKey, id> *)launchOptions {
//     dispatch_async(dispatch_get_main_queue(), ^{
//         if (self->_runFunction) self->_runFunction();
//     });
//     return YES;
// }
// #else
// - (void)applicationDidFinishLaunching:(NSNotification *)notification {
//     dispatch_async(dispatch_get_main_queue(), ^{
//         if (self->_runFunction) self->_runFunction();
//     });
// }
// #endif

// @end

comptime {
    if (builtin.cpu.arch == .x86_64) {
        if (builtin.os.tag == .macos) {
            asm (
                \\    .section __TEXT,__text,regular,pure_instructions
                \\"-[MachApp applicationDidFinishLaunching:]":
                \\
                \\    .cfi_startproc
                \\    movq __dispatch_main_q@GOTPCREL(%rip), %rdi
                \\    leaq ___block_literal_global(%rip), %rsi
                \\    jmp _dispatch_async
                \\    .cfi_endproc
                \\
                \\"___41-[MachApp applicationDidFinishLaunching:]_block_invoke":
                \\
                \\    .cfi_startproc
                \\    xorl %eax, %eax
                \\    jmp _machRun
                \\    .cfi_endproc
                \\
                \\    .section __TEXT,__cstring,cstring_literals
                \\L_.str:
                \\    .asciz "v8@?0"
                \\
                \\    .private_extern "___block_descriptor_32_e5_v8\x01?0l"
                \\    .section __DATA,__const
                \\    .globl "___block_descriptor_32_e5_v8\x01?0l"
                \\    .weak_def_can_be_hidden "___block_descriptor_32_e5_v8\x01?0l"
                \\    .p2align 3, 0x0
                \\"___block_descriptor_32_e5_v8\x01?0l":
                \\    .quad 0
                \\    .quad 32
                \\    .quad L_.str
                \\    .quad 0
                \\
                \\    .p2align 3, 0x0
                \\___block_literal_global:
                \\    .quad __NSConcreteGlobalBlock
                \\    .long 1342177280
                \\    .long 0
                \\    .quad "___41-[MachApp applicationDidFinishLaunching:]_block_invoke"
                \\    .quad "___block_descriptor_32_e5_v8\x01?0l"
                \\
                \\    .section __TEXT,__objc_classname,cstring_literals
                \\L_OBJC_CLASS_NAME_:
                \\    .asciz "MachApp"
                \\
                \\L_OBJC_CLASS_NAME_.1:
                \\    .asciz "NSApplicationDelegate"
                \\
                \\L_OBJC_CLASS_NAME_.2:
                \\    .asciz "NSObject"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\L_OBJC_METH_VAR_NAME_:
                \\    .asciz "isEqual:"
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\L_OBJC_METH_VAR_TYPE_:
                \\    .asciz "c24@0:8@16"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\L_OBJC_METH_VAR_NAME_.3:
                \\    .asciz "class"
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\L_OBJC_METH_VAR_TYPE_.4:
                \\    .asciz "#16@0:8"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\L_OBJC_METH_VAR_NAME_.5:
                \\    .asciz "self"
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\L_OBJC_METH_VAR_TYPE_.6:
                \\    .asciz "@16@0:8"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\L_OBJC_METH_VAR_NAME_.7:
                \\    .asciz "performSelector:"
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\L_OBJC_METH_VAR_TYPE_.8:
                \\    .asciz "@24@0:8:16"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\L_OBJC_METH_VAR_NAME_.9:
                \\    .asciz "performSelector:withObject:"
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\L_OBJC_METH_VAR_TYPE_.10:
                \\    .asciz "@32@0:8:16@24"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\L_OBJC_METH_VAR_NAME_.11:
                \\    .asciz "performSelector:withObject:withObject:"
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\L_OBJC_METH_VAR_TYPE_.12:
                \\    .asciz "@40@0:8:16@24@32"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\L_OBJC_METH_VAR_NAME_.13:
                \\    .asciz "isProxy"
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\L_OBJC_METH_VAR_TYPE_.14:
                \\    .asciz "c16@0:8"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\L_OBJC_METH_VAR_NAME_.15:
                \\    .asciz "isKindOfClass:"
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\L_OBJC_METH_VAR_TYPE_.16:
                \\    .asciz "c24@0:8#16"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\L_OBJC_METH_VAR_NAME_.17:
                \\    .asciz "isMemberOfClass:"
                \\
                \\L_OBJC_METH_VAR_NAME_.18:
                \\    .asciz "conformsToProtocol:"
                \\
                \\L_OBJC_METH_VAR_NAME_.19:
                \\    .asciz "respondsToSelector:"
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\L_OBJC_METH_VAR_TYPE_.20:
                \\    .asciz "c24@0:8:16"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\L_OBJC_METH_VAR_NAME_.21:
                \\    .asciz "retain"
                \\
                \\L_OBJC_METH_VAR_NAME_.22:
                \\    .asciz "release"
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\L_OBJC_METH_VAR_TYPE_.23:
                \\    .asciz "Vv16@0:8"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\L_OBJC_METH_VAR_NAME_.24:
                \\    .asciz "autorelease"
                \\
                \\L_OBJC_METH_VAR_NAME_.25:
                \\    .asciz "retainCount"
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\L_OBJC_METH_VAR_TYPE_.26:
                \\    .asciz "Q16@0:8"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\L_OBJC_METH_VAR_NAME_.27:
                \\    .asciz "zone"
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\L_OBJC_METH_VAR_TYPE_.28:
                \\    .asciz "^{_NSZone=}16@0:8"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\L_OBJC_METH_VAR_NAME_.29:
                \\    .asciz "hash"
                \\
                \\L_OBJC_METH_VAR_NAME_.30:
                \\    .asciz "superclass"
                \\
                \\L_OBJC_METH_VAR_NAME_.31:
                \\    .asciz "description"
                \\
                \\    .section __DATA,__objc_const
                \\    .p2align 3, 0x0
                \\__OBJC_$_PROTOCOL_INSTANCE_METHODS_NSObject:
                \\    .long 24
                \\    .long 19
                \\    .quad L_OBJC_METH_VAR_NAME_
                \\    .quad L_OBJC_METH_VAR_TYPE_
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.3
                \\    .quad L_OBJC_METH_VAR_TYPE_.4
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.5
                \\    .quad L_OBJC_METH_VAR_TYPE_.6
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.7
                \\    .quad L_OBJC_METH_VAR_TYPE_.8
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.9
                \\    .quad L_OBJC_METH_VAR_TYPE_.10
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.11
                \\    .quad L_OBJC_METH_VAR_TYPE_.12
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.13
                \\    .quad L_OBJC_METH_VAR_TYPE_.14
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.15
                \\    .quad L_OBJC_METH_VAR_TYPE_.16
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.17
                \\    .quad L_OBJC_METH_VAR_TYPE_.16
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.18
                \\    .quad L_OBJC_METH_VAR_TYPE_
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.19
                \\    .quad L_OBJC_METH_VAR_TYPE_.20
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.21
                \\    .quad L_OBJC_METH_VAR_TYPE_.6
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.22
                \\    .quad L_OBJC_METH_VAR_TYPE_.23
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.24
                \\    .quad L_OBJC_METH_VAR_TYPE_.6
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.25
                \\    .quad L_OBJC_METH_VAR_TYPE_.26
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.27
                \\    .quad L_OBJC_METH_VAR_TYPE_.28
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.29
                \\    .quad L_OBJC_METH_VAR_TYPE_.26
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.30
                \\    .quad L_OBJC_METH_VAR_TYPE_.4
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.31
                \\    .quad L_OBJC_METH_VAR_TYPE_.6
                \\    .quad 0
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\L_OBJC_METH_VAR_NAME_.32:
                \\    .asciz "debugDescription"
                \\
                \\    .section __DATA,__objc_const
                \\    .p2align 3, 0x0
                \\__OBJC_$_PROTOCOL_INSTANCE_METHODS_OPT_NSObject:
                \\    .long 24
                \\    .long 1
                \\    .quad L_OBJC_METH_VAR_NAME_.32
                \\    .quad L_OBJC_METH_VAR_TYPE_.6
                \\    .quad 0
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\L_OBJC_PROP_NAME_ATTR_:
                \\    .asciz "hash"
                \\
                \\L_OBJC_PROP_NAME_ATTR_.33:
                \\    .asciz "TQ,R"
                \\
                \\L_OBJC_PROP_NAME_ATTR_.34:
                \\    .asciz "superclass"
                \\
                \\L_OBJC_PROP_NAME_ATTR_.35:
                \\    .asciz "T#,R"
                \\
                \\L_OBJC_PROP_NAME_ATTR_.36:
                \\    .asciz "description"
                \\
                \\L_OBJC_PROP_NAME_ATTR_.37:
                \\    .asciz "T@\"NSString\",R,C"
                \\
                \\L_OBJC_PROP_NAME_ATTR_.38:
                \\    .asciz "debugDescription"
                \\
                \\L_OBJC_PROP_NAME_ATTR_.39:
                \\    .asciz "T@\"NSString\",?,R,C"
                \\
                \\    .section __DATA,__objc_const
                \\    .p2align 3, 0x0
                \\__OBJC_$_PROP_LIST_NSObject:
                \\    .long 16
                \\    .long 4
                \\    .quad L_OBJC_PROP_NAME_ATTR_
                \\    .quad L_OBJC_PROP_NAME_ATTR_.33
                \\    .quad L_OBJC_PROP_NAME_ATTR_.34
                \\    .quad L_OBJC_PROP_NAME_ATTR_.35
                \\    .quad L_OBJC_PROP_NAME_ATTR_.36
                \\    .quad L_OBJC_PROP_NAME_ATTR_.37
                \\    .quad L_OBJC_PROP_NAME_ATTR_.38
                \\    .quad L_OBJC_PROP_NAME_ATTR_.39
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\L_OBJC_METH_VAR_TYPE_.40:
                \\    .asciz "c24@0:8@\"Protocol\"16"
                \\
                \\L_OBJC_METH_VAR_TYPE_.41:
                \\    .asciz "@\"NSString\"16@0:8"
                \\
                \\    .section __DATA,__objc_const
                \\    .p2align 3, 0x0
                \\__OBJC_$_PROTOCOL_METHOD_TYPES_NSObject:
                \\    .quad L_OBJC_METH_VAR_TYPE_
                \\    .quad L_OBJC_METH_VAR_TYPE_.4
                \\    .quad L_OBJC_METH_VAR_TYPE_.6
                \\    .quad L_OBJC_METH_VAR_TYPE_.8
                \\    .quad L_OBJC_METH_VAR_TYPE_.10
                \\    .quad L_OBJC_METH_VAR_TYPE_.12
                \\    .quad L_OBJC_METH_VAR_TYPE_.14
                \\    .quad L_OBJC_METH_VAR_TYPE_.16
                \\    .quad L_OBJC_METH_VAR_TYPE_.16
                \\    .quad L_OBJC_METH_VAR_TYPE_.40
                \\    .quad L_OBJC_METH_VAR_TYPE_.20
                \\    .quad L_OBJC_METH_VAR_TYPE_.6
                \\    .quad L_OBJC_METH_VAR_TYPE_.23
                \\    .quad L_OBJC_METH_VAR_TYPE_.6
                \\    .quad L_OBJC_METH_VAR_TYPE_.26
                \\    .quad L_OBJC_METH_VAR_TYPE_.28
                \\    .quad L_OBJC_METH_VAR_TYPE_.26
                \\    .quad L_OBJC_METH_VAR_TYPE_.4
                \\    .quad L_OBJC_METH_VAR_TYPE_.41
                \\    .quad L_OBJC_METH_VAR_TYPE_.41
                \\
                \\    .private_extern __OBJC_PROTOCOL_$_NSObject
                \\    .section __DATA,__data
                \\    .globl __OBJC_PROTOCOL_$_NSObject
                \\    .weak_definition __OBJC_PROTOCOL_$_NSObject
                \\    .p2align 3, 0x0
                \\__OBJC_PROTOCOL_$_NSObject:
                \\    .quad 0
                \\    .quad L_OBJC_CLASS_NAME_.2
                \\    .quad 0
                \\    .quad __OBJC_$_PROTOCOL_INSTANCE_METHODS_NSObject
                \\    .quad 0
                \\    .quad __OBJC_$_PROTOCOL_INSTANCE_METHODS_OPT_NSObject
                \\    .quad 0
                \\    .quad __OBJC_$_PROP_LIST_NSObject
                \\    .long 96
                \\    .long 0
                \\    .quad __OBJC_$_PROTOCOL_METHOD_TYPES_NSObject
                \\    .quad 0
                \\    .quad 0
                \\
                \\    .private_extern __OBJC_LABEL_PROTOCOL_$_NSObject
                \\    .section __DATA,__objc_protolist,coalesced,no_dead_strip
                \\    .globl __OBJC_LABEL_PROTOCOL_$_NSObject
                \\    .weak_definition __OBJC_LABEL_PROTOCOL_$_NSObject
                \\    .p2align 3, 0x0
                \\__OBJC_LABEL_PROTOCOL_$_NSObject:
                \\    .quad __OBJC_PROTOCOL_$_NSObject
                \\
                \\    .section __DATA,__objc_const
                \\    .p2align 3, 0x0
                \\__OBJC_$_PROTOCOL_REFS_NSApplicationDelegate:
                \\    .quad 1
                \\    .quad __OBJC_PROTOCOL_$_NSObject
                \\    .quad 0
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\L_OBJC_METH_VAR_NAME_.42:
                \\    .asciz "applicationShouldTerminate:"
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\L_OBJC_METH_VAR_TYPE_.43:
                \\    .asciz "Q24@0:8@16"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\L_OBJC_METH_VAR_NAME_.44:
                \\    .asciz "application:openURLs:"
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\L_OBJC_METH_VAR_TYPE_.45:
                \\    .asciz "v32@0:8@16@24"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\L_OBJC_METH_VAR_NAME_.46:
                \\    .asciz "application:openFile:"
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\L_OBJC_METH_VAR_TYPE_.47:
                \\    .asciz "c32@0:8@16@24"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\L_OBJC_METH_VAR_NAME_.48:
                \\    .asciz "application:openFiles:"
                \\
                \\L_OBJC_METH_VAR_NAME_.49:
                \\    .asciz "application:openTempFile:"
                \\
                \\L_OBJC_METH_VAR_NAME_.50:
                \\    .asciz "applicationShouldOpenUntitledFile:"
                \\
                \\L_OBJC_METH_VAR_NAME_.51:
                \\    .asciz "applicationOpenUntitledFile:"
                \\
                \\L_OBJC_METH_VAR_NAME_.52:
                \\    .asciz "application:openFileWithoutUI:"
                \\
                \\L_OBJC_METH_VAR_NAME_.53:
                \\    .asciz "application:printFile:"
                \\
                \\L_OBJC_METH_VAR_NAME_.54:
                \\    .asciz "application:printFiles:withSettings:showPrintPanels:"
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\L_OBJC_METH_VAR_TYPE_.55:
                \\    .asciz "Q44@0:8@16@24@32c40"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\L_OBJC_METH_VAR_NAME_.56:
                \\    .asciz "applicationShouldTerminateAfterLastWindowClosed:"
                \\
                \\L_OBJC_METH_VAR_NAME_.57:
                \\    .asciz "applicationShouldHandleReopen:hasVisibleWindows:"
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\L_OBJC_METH_VAR_TYPE_.58:
                \\    .asciz "c28@0:8@16c24"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\L_OBJC_METH_VAR_NAME_.59:
                \\    .asciz "applicationDockMenu:"
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\L_OBJC_METH_VAR_TYPE_.60:
                \\    .asciz "@24@0:8@16"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\L_OBJC_METH_VAR_NAME_.61:
                \\    .asciz "application:willPresentError:"
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\L_OBJC_METH_VAR_TYPE_.62:
                \\    .asciz "@32@0:8@16@24"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\L_OBJC_METH_VAR_NAME_.63:
                \\    .asciz "application:didRegisterForRemoteNotificationsWithDeviceToken:"
                \\
                \\L_OBJC_METH_VAR_NAME_.64:
                \\    .asciz "application:didFailToRegisterForRemoteNotificationsWithError:"
                \\
                \\L_OBJC_METH_VAR_NAME_.65:
                \\    .asciz "application:didReceiveRemoteNotification:"
                \\
                \\L_OBJC_METH_VAR_NAME_.66:
                \\    .asciz "applicationSupportsSecureRestorableState:"
                \\
                \\L_OBJC_METH_VAR_NAME_.67:
                \\    .asciz "application:handlerForIntent:"
                \\
                \\L_OBJC_METH_VAR_NAME_.68:
                \\    .asciz "application:willEncodeRestorableState:"
                \\
                \\L_OBJC_METH_VAR_NAME_.69:
                \\    .asciz "application:didDecodeRestorableState:"
                \\
                \\L_OBJC_METH_VAR_NAME_.70:
                \\    .asciz "application:willContinueUserActivityWithType:"
                \\
                \\L_OBJC_METH_VAR_NAME_.71:
                \\    .asciz "application:continueUserActivity:restorationHandler:"
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\L_OBJC_METH_VAR_TYPE_.72:
                \\    .asciz "c40@0:8@16@24@?32"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\L_OBJC_METH_VAR_NAME_.73:
                \\    .asciz "application:didFailToContinueUserActivityWithType:error:"
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\L_OBJC_METH_VAR_TYPE_.74:
                \\    .asciz "v40@0:8@16@24@32"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\L_OBJC_METH_VAR_NAME_.75:
                \\    .asciz "application:didUpdateUserActivity:"
                \\
                \\L_OBJC_METH_VAR_NAME_.76:
                \\    .asciz "application:userDidAcceptCloudKitShareWithMetadata:"
                \\
                \\L_OBJC_METH_VAR_NAME_.77:
                \\    .asciz "application:delegateHandlesKey:"
                \\
                \\L_OBJC_METH_VAR_NAME_.78:
                \\    .asciz "applicationShouldAutomaticallyLocalizeKeyEquivalents:"
                \\
                \\L_OBJC_METH_VAR_NAME_.79:
                \\    .asciz "applicationWillFinishLaunching:"
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\L_OBJC_METH_VAR_TYPE_.80:
                \\    .asciz "v24@0:8@16"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\L_OBJC_METH_VAR_NAME_.81:
                \\    .asciz "applicationDidFinishLaunching:"
                \\
                \\L_OBJC_METH_VAR_NAME_.82:
                \\    .asciz "applicationWillHide:"
                \\
                \\L_OBJC_METH_VAR_NAME_.83:
                \\    .asciz "applicationDidHide:"
                \\
                \\L_OBJC_METH_VAR_NAME_.84:
                \\    .asciz "applicationWillUnhide:"
                \\
                \\L_OBJC_METH_VAR_NAME_.85:
                \\    .asciz "applicationDidUnhide:"
                \\
                \\L_OBJC_METH_VAR_NAME_.86:
                \\    .asciz "applicationWillBecomeActive:"
                \\
                \\L_OBJC_METH_VAR_NAME_.87:
                \\    .asciz "applicationDidBecomeActive:"
                \\
                \\L_OBJC_METH_VAR_NAME_.88:
                \\    .asciz "applicationWillResignActive:"
                \\
                \\L_OBJC_METH_VAR_NAME_.89:
                \\    .asciz "applicationDidResignActive:"
                \\
                \\L_OBJC_METH_VAR_NAME_.90:
                \\    .asciz "applicationWillUpdate:"
                \\
                \\L_OBJC_METH_VAR_NAME_.91:
                \\    .asciz "applicationDidUpdate:"
                \\
                \\L_OBJC_METH_VAR_NAME_.92:
                \\    .asciz "applicationWillTerminate:"
                \\
                \\L_OBJC_METH_VAR_NAME_.93:
                \\    .asciz "applicationDidChangeScreenParameters:"
                \\
                \\L_OBJC_METH_VAR_NAME_.94:
                \\    .asciz "applicationDidChangeOcclusionState:"
                \\
                \\L_OBJC_METH_VAR_NAME_.95:
                \\    .asciz "applicationProtectedDataWillBecomeUnavailable:"
                \\
                \\L_OBJC_METH_VAR_NAME_.96:
                \\    .asciz "applicationProtectedDataDidBecomeAvailable:"
                \\
                \\    .section __DATA,__objc_const
                \\    .p2align 3, 0x0
                \\__OBJC_$_PROTOCOL_INSTANCE_METHODS_OPT_NSApplicationDelegate:
                \\    .long 24
                \\    .long 45
                \\    .quad L_OBJC_METH_VAR_NAME_.42
                \\    .quad L_OBJC_METH_VAR_TYPE_.43
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.44
                \\    .quad L_OBJC_METH_VAR_TYPE_.45
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.46
                \\    .quad L_OBJC_METH_VAR_TYPE_.47
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.48
                \\    .quad L_OBJC_METH_VAR_TYPE_.45
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.49
                \\    .quad L_OBJC_METH_VAR_TYPE_.47
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.50
                \\    .quad L_OBJC_METH_VAR_TYPE_
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.51
                \\    .quad L_OBJC_METH_VAR_TYPE_
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.52
                \\    .quad L_OBJC_METH_VAR_TYPE_.47
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.53
                \\    .quad L_OBJC_METH_VAR_TYPE_.47
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.54
                \\    .quad L_OBJC_METH_VAR_TYPE_.55
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.56
                \\    .quad L_OBJC_METH_VAR_TYPE_
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.57
                \\    .quad L_OBJC_METH_VAR_TYPE_.58
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.59
                \\    .quad L_OBJC_METH_VAR_TYPE_.60
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.61
                \\    .quad L_OBJC_METH_VAR_TYPE_.62
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.63
                \\    .quad L_OBJC_METH_VAR_TYPE_.45
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.64
                \\    .quad L_OBJC_METH_VAR_TYPE_.45
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.65
                \\    .quad L_OBJC_METH_VAR_TYPE_.45
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.66
                \\    .quad L_OBJC_METH_VAR_TYPE_
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.67
                \\    .quad L_OBJC_METH_VAR_TYPE_.62
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.68
                \\    .quad L_OBJC_METH_VAR_TYPE_.45
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.69
                \\    .quad L_OBJC_METH_VAR_TYPE_.45
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.70
                \\    .quad L_OBJC_METH_VAR_TYPE_.47
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.71
                \\    .quad L_OBJC_METH_VAR_TYPE_.72
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.73
                \\    .quad L_OBJC_METH_VAR_TYPE_.74
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.75
                \\    .quad L_OBJC_METH_VAR_TYPE_.45
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.76
                \\    .quad L_OBJC_METH_VAR_TYPE_.45
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.77
                \\    .quad L_OBJC_METH_VAR_TYPE_.47
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.78
                \\    .quad L_OBJC_METH_VAR_TYPE_
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.79
                \\    .quad L_OBJC_METH_VAR_TYPE_.80
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.81
                \\    .quad L_OBJC_METH_VAR_TYPE_.80
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.82
                \\    .quad L_OBJC_METH_VAR_TYPE_.80
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.83
                \\    .quad L_OBJC_METH_VAR_TYPE_.80
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.84
                \\    .quad L_OBJC_METH_VAR_TYPE_.80
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.85
                \\    .quad L_OBJC_METH_VAR_TYPE_.80
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.86
                \\    .quad L_OBJC_METH_VAR_TYPE_.80
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.87
                \\    .quad L_OBJC_METH_VAR_TYPE_.80
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.88
                \\    .quad L_OBJC_METH_VAR_TYPE_.80
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.89
                \\    .quad L_OBJC_METH_VAR_TYPE_.80
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.90
                \\    .quad L_OBJC_METH_VAR_TYPE_.80
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.91
                \\    .quad L_OBJC_METH_VAR_TYPE_.80
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.92
                \\    .quad L_OBJC_METH_VAR_TYPE_.80
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.93
                \\    .quad L_OBJC_METH_VAR_TYPE_.80
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.94
                \\    .quad L_OBJC_METH_VAR_TYPE_.80
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.95
                \\    .quad L_OBJC_METH_VAR_TYPE_.80
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.96
                \\    .quad L_OBJC_METH_VAR_TYPE_.80
                \\    .quad 0
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\L_OBJC_METH_VAR_TYPE_.97:
                \\    .asciz "Q24@0:8@\"NSApplication\"16"
                \\
                \\L_OBJC_METH_VAR_TYPE_.98:
                \\    .asciz "v32@0:8@\"NSApplication\"16@\"NSArray\"24"
                \\
                \\L_OBJC_METH_VAR_TYPE_.99:
                \\    .asciz "c32@0:8@\"NSApplication\"16@\"NSString\"24"
                \\
                \\L_OBJC_METH_VAR_TYPE_.100:
                \\    .asciz "c24@0:8@\"NSApplication\"16"
                \\
                \\L_OBJC_METH_VAR_TYPE_.101:
                \\    .asciz "c32@0:8@16@\"NSString\"24"
                \\
                \\L_OBJC_METH_VAR_TYPE_.102:
                \\    .asciz "Q44@0:8@\"NSApplication\"16@\"NSArray\"24@\"NSDictionary\"32c40"
                \\
                \\L_OBJC_METH_VAR_TYPE_.103:
                \\    .asciz "c28@0:8@\"NSApplication\"16c24"
                \\
                \\L_OBJC_METH_VAR_TYPE_.104:
                \\    .asciz "@\"NSMenu\"24@0:8@\"NSApplication\"16"
                \\
                \\L_OBJC_METH_VAR_TYPE_.105:
                \\    .asciz "@\"NSError\"32@0:8@\"NSApplication\"16@\"NSError\"24"
                \\
                \\L_OBJC_METH_VAR_TYPE_.106:
                \\    .asciz "v32@0:8@\"NSApplication\"16@\"NSData\"24"
                \\
                \\L_OBJC_METH_VAR_TYPE_.107:
                \\    .asciz "v32@0:8@\"NSApplication\"16@\"NSError\"24"
                \\
                \\L_OBJC_METH_VAR_TYPE_.108:
                \\    .asciz "v32@0:8@\"NSApplication\"16@\"NSDictionary\"24"
                \\
                \\L_OBJC_METH_VAR_TYPE_.109:
                \\    .asciz "@32@0:8@\"NSApplication\"16@\"INIntent\"24"
                \\
                \\L_OBJC_METH_VAR_TYPE_.110:
                \\    .asciz "v32@0:8@\"NSApplication\"16@\"NSCoder\"24"
                \\
                \\L_OBJC_METH_VAR_TYPE_.111:
                \\    .asciz "c40@0:8@\"NSApplication\"16@\"NSUserActivity\"24@?<v@?@\"NSArray\">32"
                \\
                \\L_OBJC_METH_VAR_TYPE_.112:
                \\    .asciz "v40@0:8@\"NSApplication\"16@\"NSString\"24@\"NSError\"32"
                \\
                \\L_OBJC_METH_VAR_TYPE_.113:
                \\    .asciz "v32@0:8@\"NSApplication\"16@\"NSUserActivity\"24"
                \\
                \\L_OBJC_METH_VAR_TYPE_.114:
                \\    .asciz "v32@0:8@\"NSApplication\"16@\"CKShareMetadata\"24"
                \\
                \\L_OBJC_METH_VAR_TYPE_.115:
                \\    .asciz "v24@0:8@\"NSNotification\"16"
                \\
                \\    .section __DATA,__objc_const
                \\    .p2align 3, 0x0
                \\__OBJC_$_PROTOCOL_METHOD_TYPES_NSApplicationDelegate:
                \\    .quad L_OBJC_METH_VAR_TYPE_.97
                \\    .quad L_OBJC_METH_VAR_TYPE_.98
                \\    .quad L_OBJC_METH_VAR_TYPE_.99
                \\    .quad L_OBJC_METH_VAR_TYPE_.98
                \\    .quad L_OBJC_METH_VAR_TYPE_.99
                \\    .quad L_OBJC_METH_VAR_TYPE_.100
                \\    .quad L_OBJC_METH_VAR_TYPE_.100
                \\    .quad L_OBJC_METH_VAR_TYPE_.101
                \\    .quad L_OBJC_METH_VAR_TYPE_.99
                \\    .quad L_OBJC_METH_VAR_TYPE_.102
                \\    .quad L_OBJC_METH_VAR_TYPE_.100
                \\    .quad L_OBJC_METH_VAR_TYPE_.103
                \\    .quad L_OBJC_METH_VAR_TYPE_.104
                \\    .quad L_OBJC_METH_VAR_TYPE_.105
                \\    .quad L_OBJC_METH_VAR_TYPE_.106
                \\    .quad L_OBJC_METH_VAR_TYPE_.107
                \\    .quad L_OBJC_METH_VAR_TYPE_.108
                \\    .quad L_OBJC_METH_VAR_TYPE_.100
                \\    .quad L_OBJC_METH_VAR_TYPE_.109
                \\    .quad L_OBJC_METH_VAR_TYPE_.110
                \\    .quad L_OBJC_METH_VAR_TYPE_.110
                \\    .quad L_OBJC_METH_VAR_TYPE_.99
                \\    .quad L_OBJC_METH_VAR_TYPE_.111
                \\    .quad L_OBJC_METH_VAR_TYPE_.112
                \\    .quad L_OBJC_METH_VAR_TYPE_.113
                \\    .quad L_OBJC_METH_VAR_TYPE_.114
                \\    .quad L_OBJC_METH_VAR_TYPE_.99
                \\    .quad L_OBJC_METH_VAR_TYPE_.100
                \\    .quad L_OBJC_METH_VAR_TYPE_.115
                \\    .quad L_OBJC_METH_VAR_TYPE_.115
                \\    .quad L_OBJC_METH_VAR_TYPE_.115
                \\    .quad L_OBJC_METH_VAR_TYPE_.115
                \\    .quad L_OBJC_METH_VAR_TYPE_.115
                \\    .quad L_OBJC_METH_VAR_TYPE_.115
                \\    .quad L_OBJC_METH_VAR_TYPE_.115
                \\    .quad L_OBJC_METH_VAR_TYPE_.115
                \\    .quad L_OBJC_METH_VAR_TYPE_.115
                \\    .quad L_OBJC_METH_VAR_TYPE_.115
                \\    .quad L_OBJC_METH_VAR_TYPE_.115
                \\    .quad L_OBJC_METH_VAR_TYPE_.115
                \\    .quad L_OBJC_METH_VAR_TYPE_.115
                \\    .quad L_OBJC_METH_VAR_TYPE_.115
                \\    .quad L_OBJC_METH_VAR_TYPE_.115
                \\    .quad L_OBJC_METH_VAR_TYPE_.115
                \\    .quad L_OBJC_METH_VAR_TYPE_.115
                \\
                \\    .private_extern __OBJC_PROTOCOL_$_NSApplicationDelegate
                \\    .section __DATA,__data
                \\    .globl __OBJC_PROTOCOL_$_NSApplicationDelegate
                \\    .weak_definition __OBJC_PROTOCOL_$_NSApplicationDelegate
                \\    .p2align 3, 0x0
                \\__OBJC_PROTOCOL_$_NSApplicationDelegate:
                \\    .quad 0
                \\    .quad L_OBJC_CLASS_NAME_.1
                \\    .quad __OBJC_$_PROTOCOL_REFS_NSApplicationDelegate
                \\    .quad 0
                \\    .quad 0
                \\    .quad __OBJC_$_PROTOCOL_INSTANCE_METHODS_OPT_NSApplicationDelegate
                \\    .quad 0
                \\    .quad 0
                \\    .long 96
                \\    .long 0
                \\    .quad __OBJC_$_PROTOCOL_METHOD_TYPES_NSApplicationDelegate
                \\    .quad 0
                \\    .quad 0
                \\
                \\    .private_extern __OBJC_LABEL_PROTOCOL_$_NSApplicationDelegate
                \\    .section __DATA,__objc_protolist,coalesced,no_dead_strip
                \\    .globl __OBJC_LABEL_PROTOCOL_$_NSApplicationDelegate
                \\    .weak_definition __OBJC_LABEL_PROTOCOL_$_NSApplicationDelegate
                \\    .p2align 3, 0x0
                \\__OBJC_LABEL_PROTOCOL_$_NSApplicationDelegate:
                \\    .quad __OBJC_PROTOCOL_$_NSApplicationDelegate
                \\
                \\    .section __DATA,__objc_const
                \\    .p2align 3, 0x0
                \\__OBJC_CLASS_PROTOCOLS_$_MachApp:
                \\    .quad 1
                \\    .quad __OBJC_PROTOCOL_$_NSApplicationDelegate
                \\    .quad 0
                \\
                \\    .p2align 3, 0x0
                \\__OBJC_METACLASS_RO_$_MachApp:
                \\    .long 129
                \\    .long 40
                \\    .long 40
                \\    .space 4
                \\    .quad 0
                \\    .quad L_OBJC_CLASS_NAME_
                \\    .quad 0
                \\    .quad __OBJC_CLASS_PROTOCOLS_$_MachApp
                \\    .quad 0
                \\    .quad 0
                \\    .quad 0
                \\
                \\    .section __DATA,__objc_data
                \\    .globl _OBJC_METACLASS_$_MachApp
                \\    .p2align 3, 0x0
                \\_OBJC_METACLASS_$_MachApp:
                \\    .quad _OBJC_METACLASS_$_NSObject
                \\    .quad _OBJC_METACLASS_$_NSObject
                \\    .quad __objc_empty_cache
                \\    .quad 0
                \\    .quad __OBJC_METACLASS_RO_$_MachApp
                \\
                \\    .section __DATA,__objc_const
                \\    .p2align 3, 0x0
                \\__OBJC_$_INSTANCE_METHODS_MachApp:
                \\    .long 24
                \\    .long 1
                \\    .quad L_OBJC_METH_VAR_NAME_.81
                \\    .quad L_OBJC_METH_VAR_TYPE_.80
                \\    .quad "-[MachApp applicationDidFinishLaunching:]"
                \\
                \\    .p2align 3, 0x0
                \\__OBJC_$_PROP_LIST_MachApp:
                \\    .long 16
                \\    .long 4
                \\    .quad L_OBJC_PROP_NAME_ATTR_
                \\    .quad L_OBJC_PROP_NAME_ATTR_.33
                \\    .quad L_OBJC_PROP_NAME_ATTR_.34
                \\    .quad L_OBJC_PROP_NAME_ATTR_.35
                \\    .quad L_OBJC_PROP_NAME_ATTR_.36
                \\    .quad L_OBJC_PROP_NAME_ATTR_.37
                \\    .quad L_OBJC_PROP_NAME_ATTR_.38
                \\    .quad L_OBJC_PROP_NAME_ATTR_.39
                \\
                \\    .p2align 3, 0x0
                \\__OBJC_CLASS_RO_$_MachApp:
                \\    .long 128
                \\    .long 8
                \\    .long 8
                \\    .space 4
                \\    .quad 0
                \\    .quad L_OBJC_CLASS_NAME_
                \\    .quad __OBJC_$_INSTANCE_METHODS_MachApp
                \\    .quad __OBJC_CLASS_PROTOCOLS_$_MachApp
                \\    .quad 0
                \\    .quad 0
                \\    .quad __OBJC_$_PROP_LIST_MachApp
                \\
                \\    .section __DATA,__objc_data
                \\    .globl _OBJC_CLASS_$_MachApp
                \\    .p2align 3, 0x0
                \\_OBJC_CLASS_$_MachApp:
                \\    .quad _OBJC_METACLASS_$_MachApp
                \\    .quad _OBJC_CLASS_$_NSObject
                \\    .quad __objc_empty_cache
                \\    .quad 0
                \\    .quad __OBJC_CLASS_RO_$_MachApp
                \\
                \\    .section __DATA,__objc_classlist,regular,no_dead_strip
                \\    .p2align 3, 0x0
                \\l_OBJC_LABEL_CLASS_$:
                \\    .quad _OBJC_CLASS_$_MachApp
                \\
                \\    .no_dead_strip __OBJC_LABEL_PROTOCOL_$_NSApplicationDelegate
                \\    .no_dead_strip __OBJC_LABEL_PROTOCOL_$_NSObject
                \\    .no_dead_strip __OBJC_PROTOCOL_$_NSApplicationDelegate
                \\    .no_dead_strip __OBJC_PROTOCOL_$_NSObject
                \\    .section __DATA,__objc_imageinfo,regular,no_dead_strip
                \\L_OBJC_IMAGE_INFO:
                \\    .long 0
                \\    .long 64
                \\
                \\.subsections_via_symbols
            );
        } else {
            asm (
                \\    .section __TEXT,__text,regular,pure_instructions
                \\"-[MachApp application:didFinishLaunchingWithOptions:]":
                \\
                \\    .cfi_startproc
                \\    pushq %rax
                \\    .cfi_def_cfa_offset 16
                \\    movq __dispatch_main_q@GOTPCREL(%rip), %rdi
                \\    leaq ___block_literal_global(%rip), %rsi
                \\    callq _dispatch_async
                \\    movb $1, %al
                \\    popq %rcx
                \\    retq
                \\    .cfi_endproc
                \\
                \\"___53-[MachApp application:didFinishLaunchingWithOptions:]_block_invoke":
                \\
                \\    .cfi_startproc
                \\    xorl %eax, %eax
                \\    jmp _machRun
                \\    .cfi_endproc
                \\
                \\    .section __TEXT,__cstring,cstring_literals
                \\L_.str:
                \\    .asciz "v8@?0"
                \\
                \\    .private_extern "___block_descriptor_32_e5_v8\x01?0l"
                \\    .section __DATA,__const
                \\    .globl "___block_descriptor_32_e5_v8\x01?0l"
                \\    .weak_def_can_be_hidden "___block_descriptor_32_e5_v8\x01?0l"
                \\    .p2align 3, 0x0
                \\"___block_descriptor_32_e5_v8\x01?0l":
                \\    .quad 0
                \\    .quad 32
                \\    .quad L_.str
                \\    .quad 0
                \\
                \\    .p2align 3, 0x0
                \\___block_literal_global:
                \\    .quad __NSConcreteGlobalBlock
                \\    .long 1342177280
                \\    .long 0
                \\    .quad "___53-[MachApp application:didFinishLaunchingWithOptions:]_block_invoke"
                \\    .quad "___block_descriptor_32_e5_v8\x01?0l"
                \\
                \\    .section __TEXT,__objc_classname,cstring_literals
                \\L_OBJC_CLASS_NAME_:
                \\    .asciz "MachApp"
                \\
                \\L_OBJC_CLASS_NAME_.1:
                \\    .asciz "UIApplicationDelegate"
                \\
                \\L_OBJC_CLASS_NAME_.2:
                \\    .asciz "NSObject"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\L_OBJC_METH_VAR_NAME_:
                \\    .asciz "isEqual:"
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\L_OBJC_METH_VAR_TYPE_:
                \\    .asciz "B24@0:8@16"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\L_OBJC_METH_VAR_NAME_.3:
                \\    .asciz "class"
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\L_OBJC_METH_VAR_TYPE_.4:
                \\    .asciz "#16@0:8"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\L_OBJC_METH_VAR_NAME_.5:
                \\    .asciz "self"
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\L_OBJC_METH_VAR_TYPE_.6:
                \\    .asciz "@16@0:8"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\L_OBJC_METH_VAR_NAME_.7:
                \\    .asciz "performSelector:"
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\L_OBJC_METH_VAR_TYPE_.8:
                \\    .asciz "@24@0:8:16"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\L_OBJC_METH_VAR_NAME_.9:
                \\    .asciz "performSelector:withObject:"
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\L_OBJC_METH_VAR_TYPE_.10:
                \\    .asciz "@32@0:8:16@24"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\L_OBJC_METH_VAR_NAME_.11:
                \\    .asciz "performSelector:withObject:withObject:"
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\L_OBJC_METH_VAR_TYPE_.12:
                \\    .asciz "@40@0:8:16@24@32"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\L_OBJC_METH_VAR_NAME_.13:
                \\    .asciz "isProxy"
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\L_OBJC_METH_VAR_TYPE_.14:
                \\    .asciz "B16@0:8"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\L_OBJC_METH_VAR_NAME_.15:
                \\    .asciz "isKindOfClass:"
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\L_OBJC_METH_VAR_TYPE_.16:
                \\    .asciz "B24@0:8#16"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\L_OBJC_METH_VAR_NAME_.17:
                \\    .asciz "isMemberOfClass:"
                \\
                \\L_OBJC_METH_VAR_NAME_.18:
                \\    .asciz "conformsToProtocol:"
                \\
                \\L_OBJC_METH_VAR_NAME_.19:
                \\    .asciz "respondsToSelector:"
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\L_OBJC_METH_VAR_TYPE_.20:
                \\    .asciz "B24@0:8:16"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\L_OBJC_METH_VAR_NAME_.21:
                \\    .asciz "retain"
                \\
                \\L_OBJC_METH_VAR_NAME_.22:
                \\    .asciz "release"
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\L_OBJC_METH_VAR_TYPE_.23:
                \\    .asciz "Vv16@0:8"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\L_OBJC_METH_VAR_NAME_.24:
                \\    .asciz "autorelease"
                \\
                \\L_OBJC_METH_VAR_NAME_.25:
                \\    .asciz "retainCount"
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\L_OBJC_METH_VAR_TYPE_.26:
                \\    .asciz "Q16@0:8"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\L_OBJC_METH_VAR_NAME_.27:
                \\    .asciz "zone"
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\L_OBJC_METH_VAR_TYPE_.28:
                \\    .asciz "^{_NSZone=}16@0:8"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\L_OBJC_METH_VAR_NAME_.29:
                \\    .asciz "hash"
                \\
                \\L_OBJC_METH_VAR_NAME_.30:
                \\    .asciz "superclass"
                \\
                \\L_OBJC_METH_VAR_NAME_.31:
                \\    .asciz "description"
                \\
                \\    .section __DATA,__objc_const
                \\    .p2align 3, 0x0
                \\__OBJC_$_PROTOCOL_INSTANCE_METHODS_NSObject:
                \\    .long 24
                \\    .long 19
                \\    .quad L_OBJC_METH_VAR_NAME_
                \\    .quad L_OBJC_METH_VAR_TYPE_
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.3
                \\    .quad L_OBJC_METH_VAR_TYPE_.4
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.5
                \\    .quad L_OBJC_METH_VAR_TYPE_.6
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.7
                \\    .quad L_OBJC_METH_VAR_TYPE_.8
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.9
                \\    .quad L_OBJC_METH_VAR_TYPE_.10
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.11
                \\    .quad L_OBJC_METH_VAR_TYPE_.12
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.13
                \\    .quad L_OBJC_METH_VAR_TYPE_.14
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.15
                \\    .quad L_OBJC_METH_VAR_TYPE_.16
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.17
                \\    .quad L_OBJC_METH_VAR_TYPE_.16
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.18
                \\    .quad L_OBJC_METH_VAR_TYPE_
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.19
                \\    .quad L_OBJC_METH_VAR_TYPE_.20
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.21
                \\    .quad L_OBJC_METH_VAR_TYPE_.6
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.22
                \\    .quad L_OBJC_METH_VAR_TYPE_.23
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.24
                \\    .quad L_OBJC_METH_VAR_TYPE_.6
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.25
                \\    .quad L_OBJC_METH_VAR_TYPE_.26
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.27
                \\    .quad L_OBJC_METH_VAR_TYPE_.28
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.29
                \\    .quad L_OBJC_METH_VAR_TYPE_.26
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.30
                \\    .quad L_OBJC_METH_VAR_TYPE_.4
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.31
                \\    .quad L_OBJC_METH_VAR_TYPE_.6
                \\    .quad 0
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\L_OBJC_METH_VAR_NAME_.32:
                \\    .asciz "debugDescription"
                \\
                \\    .section __DATA,__objc_const
                \\    .p2align 3, 0x0
                \\__OBJC_$_PROTOCOL_INSTANCE_METHODS_OPT_NSObject:
                \\    .long 24
                \\    .long 1
                \\    .quad L_OBJC_METH_VAR_NAME_.32
                \\    .quad L_OBJC_METH_VAR_TYPE_.6
                \\    .quad 0
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\L_OBJC_PROP_NAME_ATTR_:
                \\    .asciz "hash"
                \\
                \\L_OBJC_PROP_NAME_ATTR_.33:
                \\    .asciz "TQ,R"
                \\
                \\L_OBJC_PROP_NAME_ATTR_.34:
                \\    .asciz "superclass"
                \\
                \\L_OBJC_PROP_NAME_ATTR_.35:
                \\    .asciz "T#,R"
                \\
                \\L_OBJC_PROP_NAME_ATTR_.36:
                \\    .asciz "description"
                \\
                \\L_OBJC_PROP_NAME_ATTR_.37:
                \\    .asciz "T@\"NSString\",R,C"
                \\
                \\L_OBJC_PROP_NAME_ATTR_.38:
                \\    .asciz "debugDescription"
                \\
                \\L_OBJC_PROP_NAME_ATTR_.39:
                \\    .asciz "T@\"NSString\",?,R,C"
                \\
                \\    .section __DATA,__objc_const
                \\    .p2align 3, 0x0
                \\__OBJC_$_PROP_LIST_NSObject:
                \\    .long 16
                \\    .long 4
                \\    .quad L_OBJC_PROP_NAME_ATTR_
                \\    .quad L_OBJC_PROP_NAME_ATTR_.33
                \\    .quad L_OBJC_PROP_NAME_ATTR_.34
                \\    .quad L_OBJC_PROP_NAME_ATTR_.35
                \\    .quad L_OBJC_PROP_NAME_ATTR_.36
                \\    .quad L_OBJC_PROP_NAME_ATTR_.37
                \\    .quad L_OBJC_PROP_NAME_ATTR_.38
                \\    .quad L_OBJC_PROP_NAME_ATTR_.39
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\L_OBJC_METH_VAR_TYPE_.40:
                \\    .asciz "B24@0:8@\"Protocol\"16"
                \\
                \\L_OBJC_METH_VAR_TYPE_.41:
                \\    .asciz "@\"NSString\"16@0:8"
                \\
                \\    .section __DATA,__objc_const
                \\    .p2align 3, 0x0
                \\__OBJC_$_PROTOCOL_METHOD_TYPES_NSObject:
                \\    .quad L_OBJC_METH_VAR_TYPE_
                \\    .quad L_OBJC_METH_VAR_TYPE_.4
                \\    .quad L_OBJC_METH_VAR_TYPE_.6
                \\    .quad L_OBJC_METH_VAR_TYPE_.8
                \\    .quad L_OBJC_METH_VAR_TYPE_.10
                \\    .quad L_OBJC_METH_VAR_TYPE_.12
                \\    .quad L_OBJC_METH_VAR_TYPE_.14
                \\    .quad L_OBJC_METH_VAR_TYPE_.16
                \\    .quad L_OBJC_METH_VAR_TYPE_.16
                \\    .quad L_OBJC_METH_VAR_TYPE_.40
                \\    .quad L_OBJC_METH_VAR_TYPE_.20
                \\    .quad L_OBJC_METH_VAR_TYPE_.6
                \\    .quad L_OBJC_METH_VAR_TYPE_.23
                \\    .quad L_OBJC_METH_VAR_TYPE_.6
                \\    .quad L_OBJC_METH_VAR_TYPE_.26
                \\    .quad L_OBJC_METH_VAR_TYPE_.28
                \\    .quad L_OBJC_METH_VAR_TYPE_.26
                \\    .quad L_OBJC_METH_VAR_TYPE_.4
                \\    .quad L_OBJC_METH_VAR_TYPE_.41
                \\    .quad L_OBJC_METH_VAR_TYPE_.41
                \\
                \\    .private_extern __OBJC_PROTOCOL_$_NSObject
                \\    .section __DATA,__data
                \\    .globl __OBJC_PROTOCOL_$_NSObject
                \\    .weak_definition __OBJC_PROTOCOL_$_NSObject
                \\    .p2align 3, 0x0
                \\__OBJC_PROTOCOL_$_NSObject:
                \\    .quad 0
                \\    .quad L_OBJC_CLASS_NAME_.2
                \\    .quad 0
                \\    .quad __OBJC_$_PROTOCOL_INSTANCE_METHODS_NSObject
                \\    .quad 0
                \\    .quad __OBJC_$_PROTOCOL_INSTANCE_METHODS_OPT_NSObject
                \\    .quad 0
                \\    .quad __OBJC_$_PROP_LIST_NSObject
                \\    .long 96
                \\    .long 0
                \\    .quad __OBJC_$_PROTOCOL_METHOD_TYPES_NSObject
                \\    .quad 0
                \\    .quad 0
                \\
                \\    .private_extern __OBJC_LABEL_PROTOCOL_$_NSObject
                \\    .section __DATA,__objc_protolist,coalesced,no_dead_strip
                \\    .globl __OBJC_LABEL_PROTOCOL_$_NSObject
                \\    .weak_definition __OBJC_LABEL_PROTOCOL_$_NSObject
                \\    .p2align 3, 0x0
                \\__OBJC_LABEL_PROTOCOL_$_NSObject:
                \\    .quad __OBJC_PROTOCOL_$_NSObject
                \\
                \\    .section __DATA,__objc_const
                \\    .p2align 3, 0x0
                \\__OBJC_$_PROTOCOL_REFS_UIApplicationDelegate:
                \\    .quad 1
                \\    .quad __OBJC_PROTOCOL_$_NSObject
                \\    .quad 0
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\L_OBJC_METH_VAR_NAME_.42:
                \\    .asciz "applicationDidFinishLaunching:"
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\L_OBJC_METH_VAR_TYPE_.43:
                \\    .asciz "v24@0:8@16"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\L_OBJC_METH_VAR_NAME_.44:
                \\    .asciz "application:willFinishLaunchingWithOptions:"
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\L_OBJC_METH_VAR_TYPE_.45:
                \\    .asciz "B32@0:8@16@24"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\L_OBJC_METH_VAR_NAME_.46:
                \\    .asciz "application:didFinishLaunchingWithOptions:"
                \\
                \\L_OBJC_METH_VAR_NAME_.47:
                \\    .asciz "applicationDidBecomeActive:"
                \\
                \\L_OBJC_METH_VAR_NAME_.48:
                \\    .asciz "applicationWillResignActive:"
                \\
                \\L_OBJC_METH_VAR_NAME_.49:
                \\    .asciz "application:handleOpenURL:"
                \\
                \\L_OBJC_METH_VAR_NAME_.50:
                \\    .asciz "application:openURL:sourceApplication:annotation:"
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\L_OBJC_METH_VAR_TYPE_.51:
                \\    .asciz "B48@0:8@16@24@32@40"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\L_OBJC_METH_VAR_NAME_.52:
                \\    .asciz "application:openURL:options:"
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\L_OBJC_METH_VAR_TYPE_.53:
                \\    .asciz "B40@0:8@16@24@32"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\L_OBJC_METH_VAR_NAME_.54:
                \\    .asciz "applicationDidReceiveMemoryWarning:"
                \\
                \\L_OBJC_METH_VAR_NAME_.55:
                \\    .asciz "applicationWillTerminate:"
                \\
                \\L_OBJC_METH_VAR_NAME_.56:
                \\    .asciz "applicationSignificantTimeChange:"
                \\
                \\L_OBJC_METH_VAR_NAME_.57:
                \\    .asciz "application:willChangeStatusBarOrientation:duration:"
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\L_OBJC_METH_VAR_TYPE_.58:
                \\    .asciz "v40@0:8@16q24d32"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\L_OBJC_METH_VAR_NAME_.59:
                \\    .asciz "application:didChangeStatusBarOrientation:"
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\L_OBJC_METH_VAR_TYPE_.60:
                \\    .asciz "v32@0:8@16q24"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\L_OBJC_METH_VAR_NAME_.61:
                \\    .asciz "application:willChangeStatusBarFrame:"
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\L_OBJC_METH_VAR_TYPE_.62:
                \\    .asciz "v56@0:8@16{CGRect={CGPoint=dd}{CGSize=dd}}24"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\L_OBJC_METH_VAR_NAME_.63:
                \\    .asciz "application:didChangeStatusBarFrame:"
                \\
                \\L_OBJC_METH_VAR_NAME_.64:
                \\    .asciz "application:didRegisterUserNotificationSettings:"
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\L_OBJC_METH_VAR_TYPE_.65:
                \\    .asciz "v32@0:8@16@24"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\L_OBJC_METH_VAR_NAME_.66:
                \\    .asciz "application:didRegisterForRemoteNotificationsWithDeviceToken:"
                \\
                \\L_OBJC_METH_VAR_NAME_.67:
                \\    .asciz "application:didFailToRegisterForRemoteNotificationsWithError:"
                \\
                \\L_OBJC_METH_VAR_NAME_.68:
                \\    .asciz "application:didReceiveRemoteNotification:"
                \\
                \\L_OBJC_METH_VAR_NAME_.69:
                \\    .asciz "application:didReceiveLocalNotification:"
                \\
                \\L_OBJC_METH_VAR_NAME_.70:
                \\    .asciz "application:handleActionWithIdentifier:forLocalNotification:completionHandler:"
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\L_OBJC_METH_VAR_TYPE_.71:
                \\    .asciz "v48@0:8@16@24@32@?40"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\L_OBJC_METH_VAR_NAME_.72:
                \\    .asciz "application:handleActionWithIdentifier:forRemoteNotification:withResponseInfo:completionHandler:"
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\L_OBJC_METH_VAR_TYPE_.73:
                \\    .asciz "v56@0:8@16@24@32@40@?48"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\L_OBJC_METH_VAR_NAME_.74:
                \\    .asciz "application:handleActionWithIdentifier:forRemoteNotification:completionHandler:"
                \\
                \\L_OBJC_METH_VAR_NAME_.75:
                \\    .asciz "application:handleActionWithIdentifier:forLocalNotification:withResponseInfo:completionHandler:"
                \\
                \\L_OBJC_METH_VAR_NAME_.76:
                \\    .asciz "application:didReceiveRemoteNotification:fetchCompletionHandler:"
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\L_OBJC_METH_VAR_TYPE_.77:
                \\    .asciz "v40@0:8@16@24@?32"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\L_OBJC_METH_VAR_NAME_.78:
                \\    .asciz "application:performFetchWithCompletionHandler:"
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\L_OBJC_METH_VAR_TYPE_.79:
                \\    .asciz "v32@0:8@16@?24"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\L_OBJC_METH_VAR_NAME_.80:
                \\    .asciz "application:performActionForShortcutItem:completionHandler:"
                \\
                \\L_OBJC_METH_VAR_NAME_.81:
                \\    .asciz "application:handleEventsForBackgroundURLSession:completionHandler:"
                \\
                \\L_OBJC_METH_VAR_NAME_.82:
                \\    .asciz "application:handleWatchKitExtensionRequest:reply:"
                \\
                \\L_OBJC_METH_VAR_NAME_.83:
                \\    .asciz "applicationShouldRequestHealthAuthorization:"
                \\
                \\L_OBJC_METH_VAR_NAME_.84:
                \\    .asciz "application:handlerForIntent:"
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\L_OBJC_METH_VAR_TYPE_.85:
                \\    .asciz "@32@0:8@16@24"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\L_OBJC_METH_VAR_NAME_.86:
                \\    .asciz "application:handleIntent:completionHandler:"
                \\
                \\L_OBJC_METH_VAR_NAME_.87:
                \\    .asciz "applicationDidEnterBackground:"
                \\
                \\L_OBJC_METH_VAR_NAME_.88:
                \\    .asciz "applicationWillEnterForeground:"
                \\
                \\L_OBJC_METH_VAR_NAME_.89:
                \\    .asciz "applicationProtectedDataWillBecomeUnavailable:"
                \\
                \\L_OBJC_METH_VAR_NAME_.90:
                \\    .asciz "applicationProtectedDataDidBecomeAvailable:"
                \\
                \\L_OBJC_METH_VAR_NAME_.91:
                \\    .asciz "application:supportedInterfaceOrientationsForWindow:"
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\L_OBJC_METH_VAR_TYPE_.92:
                \\    .asciz "Q32@0:8@16@24"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\L_OBJC_METH_VAR_NAME_.93:
                \\    .asciz "application:shouldAllowExtensionPointIdentifier:"
                \\
                \\L_OBJC_METH_VAR_NAME_.94:
                \\    .asciz "application:viewControllerWithRestorationIdentifierPath:coder:"
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\L_OBJC_METH_VAR_TYPE_.95:
                \\    .asciz "@40@0:8@16@24@32"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\L_OBJC_METH_VAR_NAME_.96:
                \\    .asciz "application:shouldSaveSecureApplicationState:"
                \\
                \\L_OBJC_METH_VAR_NAME_.97:
                \\    .asciz "application:shouldRestoreSecureApplicationState:"
                \\
                \\L_OBJC_METH_VAR_NAME_.98:
                \\    .asciz "application:willEncodeRestorableStateWithCoder:"
                \\
                \\L_OBJC_METH_VAR_NAME_.99:
                \\    .asciz "application:didDecodeRestorableStateWithCoder:"
                \\
                \\L_OBJC_METH_VAR_NAME_.100:
                \\    .asciz "application:shouldSaveApplicationState:"
                \\
                \\L_OBJC_METH_VAR_NAME_.101:
                \\    .asciz "application:shouldRestoreApplicationState:"
                \\
                \\L_OBJC_METH_VAR_NAME_.102:
                \\    .asciz "application:willContinueUserActivityWithType:"
                \\
                \\L_OBJC_METH_VAR_NAME_.103:
                \\    .asciz "application:continueUserActivity:restorationHandler:"
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\L_OBJC_METH_VAR_TYPE_.104:
                \\    .asciz "B40@0:8@16@24@?32"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\L_OBJC_METH_VAR_NAME_.105:
                \\    .asciz "application:didFailToContinueUserActivityWithType:error:"
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\L_OBJC_METH_VAR_TYPE_.106:
                \\    .asciz "v40@0:8@16@24@32"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\L_OBJC_METH_VAR_NAME_.107:
                \\    .asciz "application:didUpdateUserActivity:"
                \\
                \\L_OBJC_METH_VAR_NAME_.108:
                \\    .asciz "application:userDidAcceptCloudKitShareWithMetadata:"
                \\
                \\L_OBJC_METH_VAR_NAME_.109:
                \\    .asciz "application:configurationForConnectingSceneSession:options:"
                \\
                \\L_OBJC_METH_VAR_NAME_.110:
                \\    .asciz "application:didDiscardSceneSessions:"
                \\
                \\L_OBJC_METH_VAR_NAME_.111:
                \\    .asciz "applicationShouldAutomaticallyLocalizeKeyCommands:"
                \\
                \\L_OBJC_METH_VAR_NAME_.112:
                \\    .asciz "window"
                \\
                \\L_OBJC_METH_VAR_NAME_.113:
                \\    .asciz "setWindow:"
                \\
                \\    .section __DATA,__objc_const
                \\    .p2align 3, 0x0
                \\__OBJC_$_PROTOCOL_INSTANCE_METHODS_OPT_UIApplicationDelegate:
                \\    .long 24
                \\    .long 55
                \\    .quad L_OBJC_METH_VAR_NAME_.42
                \\    .quad L_OBJC_METH_VAR_TYPE_.43
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.44
                \\    .quad L_OBJC_METH_VAR_TYPE_.45
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.46
                \\    .quad L_OBJC_METH_VAR_TYPE_.45
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.47
                \\    .quad L_OBJC_METH_VAR_TYPE_.43
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.48
                \\    .quad L_OBJC_METH_VAR_TYPE_.43
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.49
                \\    .quad L_OBJC_METH_VAR_TYPE_.45
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.50
                \\    .quad L_OBJC_METH_VAR_TYPE_.51
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.52
                \\    .quad L_OBJC_METH_VAR_TYPE_.53
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.54
                \\    .quad L_OBJC_METH_VAR_TYPE_.43
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.55
                \\    .quad L_OBJC_METH_VAR_TYPE_.43
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.56
                \\    .quad L_OBJC_METH_VAR_TYPE_.43
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.57
                \\    .quad L_OBJC_METH_VAR_TYPE_.58
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.59
                \\    .quad L_OBJC_METH_VAR_TYPE_.60
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.61
                \\    .quad L_OBJC_METH_VAR_TYPE_.62
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.63
                \\    .quad L_OBJC_METH_VAR_TYPE_.62
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.64
                \\    .quad L_OBJC_METH_VAR_TYPE_.65
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.66
                \\    .quad L_OBJC_METH_VAR_TYPE_.65
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.67
                \\    .quad L_OBJC_METH_VAR_TYPE_.65
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.68
                \\    .quad L_OBJC_METH_VAR_TYPE_.65
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.69
                \\    .quad L_OBJC_METH_VAR_TYPE_.65
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.70
                \\    .quad L_OBJC_METH_VAR_TYPE_.71
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.72
                \\    .quad L_OBJC_METH_VAR_TYPE_.73
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.74
                \\    .quad L_OBJC_METH_VAR_TYPE_.71
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.75
                \\    .quad L_OBJC_METH_VAR_TYPE_.73
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.76
                \\    .quad L_OBJC_METH_VAR_TYPE_.77
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.78
                \\    .quad L_OBJC_METH_VAR_TYPE_.79
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.80
                \\    .quad L_OBJC_METH_VAR_TYPE_.77
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.81
                \\    .quad L_OBJC_METH_VAR_TYPE_.77
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.82
                \\    .quad L_OBJC_METH_VAR_TYPE_.77
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.83
                \\    .quad L_OBJC_METH_VAR_TYPE_.43
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.84
                \\    .quad L_OBJC_METH_VAR_TYPE_.85
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.86
                \\    .quad L_OBJC_METH_VAR_TYPE_.77
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.87
                \\    .quad L_OBJC_METH_VAR_TYPE_.43
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.88
                \\    .quad L_OBJC_METH_VAR_TYPE_.43
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.89
                \\    .quad L_OBJC_METH_VAR_TYPE_.43
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.90
                \\    .quad L_OBJC_METH_VAR_TYPE_.43
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.91
                \\    .quad L_OBJC_METH_VAR_TYPE_.92
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.93
                \\    .quad L_OBJC_METH_VAR_TYPE_.45
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.94
                \\    .quad L_OBJC_METH_VAR_TYPE_.95
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.96
                \\    .quad L_OBJC_METH_VAR_TYPE_.45
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.97
                \\    .quad L_OBJC_METH_VAR_TYPE_.45
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.98
                \\    .quad L_OBJC_METH_VAR_TYPE_.65
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.99
                \\    .quad L_OBJC_METH_VAR_TYPE_.65
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.100
                \\    .quad L_OBJC_METH_VAR_TYPE_.45
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.101
                \\    .quad L_OBJC_METH_VAR_TYPE_.45
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.102
                \\    .quad L_OBJC_METH_VAR_TYPE_.45
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.103
                \\    .quad L_OBJC_METH_VAR_TYPE_.104
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.105
                \\    .quad L_OBJC_METH_VAR_TYPE_.106
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.107
                \\    .quad L_OBJC_METH_VAR_TYPE_.65
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.108
                \\    .quad L_OBJC_METH_VAR_TYPE_.65
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.109
                \\    .quad L_OBJC_METH_VAR_TYPE_.95
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.110
                \\    .quad L_OBJC_METH_VAR_TYPE_.65
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.111
                \\    .quad L_OBJC_METH_VAR_TYPE_
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.112
                \\    .quad L_OBJC_METH_VAR_TYPE_.6
                \\    .quad 0
                \\    .quad L_OBJC_METH_VAR_NAME_.113
                \\    .quad L_OBJC_METH_VAR_TYPE_.43
                \\    .quad 0
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\L_OBJC_PROP_NAME_ATTR_.114:
                \\    .asciz "window"
                \\
                \\L_OBJC_PROP_NAME_ATTR_.115:
                \\    .asciz "T@\"UIWindow\",?,&,N"
                \\
                \\    .section __DATA,__objc_const
                \\    .p2align 3, 0x0
                \\__OBJC_$_PROP_LIST_UIApplicationDelegate:
                \\    .long 16
                \\    .long 1
                \\    .quad L_OBJC_PROP_NAME_ATTR_.114
                \\    .quad L_OBJC_PROP_NAME_ATTR_.115
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\L_OBJC_METH_VAR_TYPE_.116:
                \\    .asciz "v24@0:8@\"UIApplication\"16"
                \\
                \\L_OBJC_METH_VAR_TYPE_.117:
                \\    .asciz "B32@0:8@\"UIApplication\"16@\"NSDictionary\"24"
                \\
                \\L_OBJC_METH_VAR_TYPE_.118:
                \\    .asciz "B32@0:8@\"UIApplication\"16@\"NSURL\"24"
                \\
                \\L_OBJC_METH_VAR_TYPE_.119:
                \\    .asciz "B48@0:8@\"UIApplication\"16@\"NSURL\"24@\"NSString\"32@40"
                \\
                \\L_OBJC_METH_VAR_TYPE_.120:
                \\    .asciz "B40@0:8@\"UIApplication\"16@\"NSURL\"24@\"NSDictionary\"32"
                \\
                \\L_OBJC_METH_VAR_TYPE_.121:
                \\    .asciz "v40@0:8@\"UIApplication\"16q24d32"
                \\
                \\L_OBJC_METH_VAR_TYPE_.122:
                \\    .asciz "v32@0:8@\"UIApplication\"16q24"
                \\
                \\L_OBJC_METH_VAR_TYPE_.123:
                \\    .asciz "v56@0:8@\"UIApplication\"16{CGRect={CGPoint=dd}{CGSize=dd}}24"
                \\
                \\L_OBJC_METH_VAR_TYPE_.124:
                \\    .asciz "v32@0:8@\"UIApplication\"16@\"UIUserNotificationSettings\"24"
                \\
                \\L_OBJC_METH_VAR_TYPE_.125:
                \\    .asciz "v32@0:8@\"UIApplication\"16@\"NSData\"24"
                \\
                \\L_OBJC_METH_VAR_TYPE_.126:
                \\    .asciz "v32@0:8@\"UIApplication\"16@\"NSError\"24"
                \\
                \\L_OBJC_METH_VAR_TYPE_.127:
                \\    .asciz "v32@0:8@\"UIApplication\"16@\"NSDictionary\"24"
                \\
                \\L_OBJC_METH_VAR_TYPE_.128:
                \\    .asciz "v32@0:8@\"UIApplication\"16@\"UILocalNotification\"24"
                \\
                \\L_OBJC_METH_VAR_TYPE_.129:
                \\    .asciz "v48@0:8@\"UIApplication\"16@\"NSString\"24@\"UILocalNotification\"32@?<v@?>40"
                \\
                \\L_OBJC_METH_VAR_TYPE_.130:
                \\    .asciz "v56@0:8@\"UIApplication\"16@\"NSString\"24@\"NSDictionary\"32@\"NSDictionary\"40@?<v@?>48"
                \\
                \\L_OBJC_METH_VAR_TYPE_.131:
                \\    .asciz "v48@0:8@\"UIApplication\"16@\"NSString\"24@\"NSDictionary\"32@?<v@?>40"
                \\
                \\L_OBJC_METH_VAR_TYPE_.132:
                \\    .asciz "v56@0:8@\"UIApplication\"16@\"NSString\"24@\"UILocalNotification\"32@\"NSDictionary\"40@?<v@?>48"
                \\
                \\L_OBJC_METH_VAR_TYPE_.133:
                \\    .asciz "v40@0:8@\"UIApplication\"16@\"NSDictionary\"24@?<v@?Q>32"
                \\
                \\L_OBJC_METH_VAR_TYPE_.134:
                \\    .asciz "v32@0:8@\"UIApplication\"16@?<v@?Q>24"
                \\
                \\L_OBJC_METH_VAR_TYPE_.135:
                \\    .asciz "v40@0:8@\"UIApplication\"16@\"UIApplicationShortcutItem\"24@?<v@?B>32"
                \\
                \\L_OBJC_METH_VAR_TYPE_.136:
                \\    .asciz "v40@0:8@\"UIApplication\"16@\"NSString\"24@?<v@?>32"
                \\
                \\L_OBJC_METH_VAR_TYPE_.137:
                \\    .asciz "v40@0:8@\"UIApplication\"16@\"NSDictionary\"24@?<v@?@\"NSDictionary\">32"
                \\
                \\L_OBJC_METH_VAR_TYPE_.138:
                \\    .asciz "@32@0:8@\"UIApplication\"16@\"INIntent\"24"
                \\
                \\L_OBJC_METH_VAR_TYPE_.139:
                \\    .asciz "v40@0:8@\"UIApplication\"16@\"INIntent\"24@?<v@?@\"INIntentResponse\">32"
                \\
                \\L_OBJC_METH_VAR_TYPE_.140:
                \\    .asciz "Q32@0:8@\"UIApplication\"16@\"UIWindow\"24"
                \\
                \\L_OBJC_METH_VAR_TYPE_.141:
                \\    .asciz "B32@0:8@\"UIApplication\"16@\"NSString\"24"
                \\
                \\L_OBJC_METH_VAR_TYPE_.142:
                \\    .asciz "@\"UIViewController\"40@0:8@\"UIApplication\"16@\"NSArray\"24@\"NSCoder\"32"
                \\
                \\L_OBJC_METH_VAR_TYPE_.143:
                \\    .asciz "B32@0:8@\"UIApplication\"16@\"NSCoder\"24"
                \\
                \\L_OBJC_METH_VAR_TYPE_.144:
                \\    .asciz "v32@0:8@\"UIApplication\"16@\"NSCoder\"24"
                \\
                \\L_OBJC_METH_VAR_TYPE_.145:
                \\    .asciz "B40@0:8@\"UIApplication\"16@\"NSUserActivity\"24@?<v@?@\"NSArray\">32"
                \\
                \\L_OBJC_METH_VAR_TYPE_.146:
                \\    .asciz "v40@0:8@\"UIApplication\"16@\"NSString\"24@\"NSError\"32"
                \\
                \\L_OBJC_METH_VAR_TYPE_.147:
                \\    .asciz "v32@0:8@\"UIApplication\"16@\"NSUserActivity\"24"
                \\
                \\L_OBJC_METH_VAR_TYPE_.148:
                \\    .asciz "v32@0:8@\"UIApplication\"16@\"CKShareMetadata\"24"
                \\
                \\L_OBJC_METH_VAR_TYPE_.149:
                \\    .asciz "@\"UISceneConfiguration\"40@0:8@\"UIApplication\"16@\"UISceneSession\"24@\"UISceneConnectionOptions\"32"
                \\
                \\L_OBJC_METH_VAR_TYPE_.150:
                \\    .asciz "v32@0:8@\"UIApplication\"16@\"NSSet\"24"
                \\
                \\L_OBJC_METH_VAR_TYPE_.151:
                \\    .asciz "B24@0:8@\"UIApplication\"16"
                \\
                \\L_OBJC_METH_VAR_TYPE_.152:
                \\    .asciz "@\"UIWindow\"16@0:8"
                \\
                \\L_OBJC_METH_VAR_TYPE_.153:
                \\    .asciz "v24@0:8@\"UIWindow\"16"
                \\
                \\    .section __DATA,__objc_const
                \\    .p2align 3, 0x0
                \\__OBJC_$_PROTOCOL_METHOD_TYPES_UIApplicationDelegate:
                \\    .quad L_OBJC_METH_VAR_TYPE_.116
                \\    .quad L_OBJC_METH_VAR_TYPE_.117
                \\    .quad L_OBJC_METH_VAR_TYPE_.117
                \\    .quad L_OBJC_METH_VAR_TYPE_.116
                \\    .quad L_OBJC_METH_VAR_TYPE_.116
                \\    .quad L_OBJC_METH_VAR_TYPE_.118
                \\    .quad L_OBJC_METH_VAR_TYPE_.119
                \\    .quad L_OBJC_METH_VAR_TYPE_.120
                \\    .quad L_OBJC_METH_VAR_TYPE_.116
                \\    .quad L_OBJC_METH_VAR_TYPE_.116
                \\    .quad L_OBJC_METH_VAR_TYPE_.116
                \\    .quad L_OBJC_METH_VAR_TYPE_.121
                \\    .quad L_OBJC_METH_VAR_TYPE_.122
                \\    .quad L_OBJC_METH_VAR_TYPE_.123
                \\    .quad L_OBJC_METH_VAR_TYPE_.123
                \\    .quad L_OBJC_METH_VAR_TYPE_.124
                \\    .quad L_OBJC_METH_VAR_TYPE_.125
                \\    .quad L_OBJC_METH_VAR_TYPE_.126
                \\    .quad L_OBJC_METH_VAR_TYPE_.127
                \\    .quad L_OBJC_METH_VAR_TYPE_.128
                \\    .quad L_OBJC_METH_VAR_TYPE_.129
                \\    .quad L_OBJC_METH_VAR_TYPE_.130
                \\    .quad L_OBJC_METH_VAR_TYPE_.131
                \\    .quad L_OBJC_METH_VAR_TYPE_.132
                \\    .quad L_OBJC_METH_VAR_TYPE_.133
                \\    .quad L_OBJC_METH_VAR_TYPE_.134
                \\    .quad L_OBJC_METH_VAR_TYPE_.135
                \\    .quad L_OBJC_METH_VAR_TYPE_.136
                \\    .quad L_OBJC_METH_VAR_TYPE_.137
                \\    .quad L_OBJC_METH_VAR_TYPE_.116
                \\    .quad L_OBJC_METH_VAR_TYPE_.138
                \\    .quad L_OBJC_METH_VAR_TYPE_.139
                \\    .quad L_OBJC_METH_VAR_TYPE_.116
                \\    .quad L_OBJC_METH_VAR_TYPE_.116
                \\    .quad L_OBJC_METH_VAR_TYPE_.116
                \\    .quad L_OBJC_METH_VAR_TYPE_.116
                \\    .quad L_OBJC_METH_VAR_TYPE_.140
                \\    .quad L_OBJC_METH_VAR_TYPE_.141
                \\    .quad L_OBJC_METH_VAR_TYPE_.142
                \\    .quad L_OBJC_METH_VAR_TYPE_.143
                \\    .quad L_OBJC_METH_VAR_TYPE_.143
                \\    .quad L_OBJC_METH_VAR_TYPE_.144
                \\    .quad L_OBJC_METH_VAR_TYPE_.144
                \\    .quad L_OBJC_METH_VAR_TYPE_.143
                \\    .quad L_OBJC_METH_VAR_TYPE_.143
                \\    .quad L_OBJC_METH_VAR_TYPE_.141
                \\    .quad L_OBJC_METH_VAR_TYPE_.145
                \\    .quad L_OBJC_METH_VAR_TYPE_.146
                \\    .quad L_OBJC_METH_VAR_TYPE_.147
                \\    .quad L_OBJC_METH_VAR_TYPE_.148
                \\    .quad L_OBJC_METH_VAR_TYPE_.149
                \\    .quad L_OBJC_METH_VAR_TYPE_.150
                \\    .quad L_OBJC_METH_VAR_TYPE_.151
                \\    .quad L_OBJC_METH_VAR_TYPE_.152
                \\    .quad L_OBJC_METH_VAR_TYPE_.153
                \\
                \\    .private_extern __OBJC_PROTOCOL_$_UIApplicationDelegate
                \\    .section __DATA,__data
                \\    .globl __OBJC_PROTOCOL_$_UIApplicationDelegate
                \\    .weak_definition __OBJC_PROTOCOL_$_UIApplicationDelegate
                \\    .p2align 3, 0x0
                \\__OBJC_PROTOCOL_$_UIApplicationDelegate:
                \\    .quad 0
                \\    .quad L_OBJC_CLASS_NAME_.1
                \\    .quad __OBJC_$_PROTOCOL_REFS_UIApplicationDelegate
                \\    .quad 0
                \\    .quad 0
                \\    .quad __OBJC_$_PROTOCOL_INSTANCE_METHODS_OPT_UIApplicationDelegate
                \\    .quad 0
                \\    .quad __OBJC_$_PROP_LIST_UIApplicationDelegate
                \\    .long 96
                \\    .long 0
                \\    .quad __OBJC_$_PROTOCOL_METHOD_TYPES_UIApplicationDelegate
                \\    .quad 0
                \\    .quad 0
                \\
                \\    .private_extern __OBJC_LABEL_PROTOCOL_$_UIApplicationDelegate
                \\    .section __DATA,__objc_protolist,coalesced,no_dead_strip
                \\    .globl __OBJC_LABEL_PROTOCOL_$_UIApplicationDelegate
                \\    .weak_definition __OBJC_LABEL_PROTOCOL_$_UIApplicationDelegate
                \\    .p2align 3, 0x0
                \\__OBJC_LABEL_PROTOCOL_$_UIApplicationDelegate:
                \\    .quad __OBJC_PROTOCOL_$_UIApplicationDelegate
                \\
                \\    .section __DATA,__objc_const
                \\    .p2align 3, 0x0
                \\__OBJC_CLASS_PROTOCOLS_$_MachApp:
                \\    .quad 1
                \\    .quad __OBJC_PROTOCOL_$_UIApplicationDelegate
                \\    .quad 0
                \\
                \\    .p2align 3, 0x0
                \\__OBJC_METACLASS_RO_$_MachApp:
                \\    .long 129
                \\    .long 40
                \\    .long 40
                \\    .space 4
                \\    .quad 0
                \\    .quad L_OBJC_CLASS_NAME_
                \\    .quad 0
                \\    .quad __OBJC_CLASS_PROTOCOLS_$_MachApp
                \\    .quad 0
                \\    .quad 0
                \\    .quad 0
                \\
                \\    .section __DATA,__objc_data
                \\    .globl _OBJC_METACLASS_$_MachApp
                \\    .p2align 3, 0x0
                \\_OBJC_METACLASS_$_MachApp:
                \\    .quad _OBJC_METACLASS_$_NSObject
                \\    .quad _OBJC_METACLASS_$_NSObject
                \\    .quad __objc_empty_cache
                \\    .quad 0
                \\    .quad __OBJC_METACLASS_RO_$_MachApp
                \\
                \\    .section __DATA,__objc_const
                \\    .p2align 3, 0x0
                \\__OBJC_$_INSTANCE_METHODS_MachApp:
                \\    .long 24
                \\    .long 1
                \\    .quad L_OBJC_METH_VAR_NAME_.46
                \\    .quad L_OBJC_METH_VAR_TYPE_.45
                \\    .quad "-[MachApp application:didFinishLaunchingWithOptions:]"
                \\
                \\    .p2align 3, 0x0
                \\__OBJC_$_PROP_LIST_MachApp:
                \\    .long 16
                \\    .long 5
                \\    .quad L_OBJC_PROP_NAME_ATTR_.114
                \\    .quad L_OBJC_PROP_NAME_ATTR_.115
                \\    .quad L_OBJC_PROP_NAME_ATTR_
                \\    .quad L_OBJC_PROP_NAME_ATTR_.33
                \\    .quad L_OBJC_PROP_NAME_ATTR_.34
                \\    .quad L_OBJC_PROP_NAME_ATTR_.35
                \\    .quad L_OBJC_PROP_NAME_ATTR_.36
                \\    .quad L_OBJC_PROP_NAME_ATTR_.37
                \\    .quad L_OBJC_PROP_NAME_ATTR_.38
                \\    .quad L_OBJC_PROP_NAME_ATTR_.39
                \\
                \\    .p2align 3, 0x0
                \\__OBJC_CLASS_RO_$_MachApp:
                \\    .long 128
                \\    .long 8
                \\    .long 8
                \\    .space 4
                \\    .quad 0
                \\    .quad L_OBJC_CLASS_NAME_
                \\    .quad __OBJC_$_INSTANCE_METHODS_MachApp
                \\    .quad __OBJC_CLASS_PROTOCOLS_$_MachApp
                \\    .quad 0
                \\    .quad 0
                \\    .quad __OBJC_$_PROP_LIST_MachApp
                \\
                \\    .section __DATA,__objc_data
                \\    .globl _OBJC_CLASS_$_MachApp
                \\    .p2align 3, 0x0
                \\_OBJC_CLASS_$_MachApp:
                \\    .quad _OBJC_METACLASS_$_MachApp
                \\    .quad _OBJC_CLASS_$_NSObject
                \\    .quad __objc_empty_cache
                \\    .quad 0
                \\    .quad __OBJC_CLASS_RO_$_MachApp
                \\
                \\    .section __DATA,__objc_classlist,regular,no_dead_strip
                \\    .p2align 3, 0x0
                \\l_OBJC_LABEL_CLASS_$:
                \\    .quad _OBJC_CLASS_$_MachApp
                \\
                \\    .no_dead_strip __OBJC_LABEL_PROTOCOL_$_NSObject
                \\    .no_dead_strip __OBJC_LABEL_PROTOCOL_$_UIApplicationDelegate
                \\    .no_dead_strip __OBJC_PROTOCOL_$_NSObject
                \\    .no_dead_strip __OBJC_PROTOCOL_$_UIApplicationDelegate
                \\    .section __DATA,__objc_imageinfo,regular,no_dead_strip
                \\L_OBJC_IMAGE_INFO:
                \\    .long 0
                \\    .long 96
                \\
                \\.subsections_via_symbols
            );
        }
    } else {
        if (builtin.os.tag == .macos) {
            asm (
                \\    .section __TEXT,__text,regular,pure_instructions
                \\    .p2align 2
                \\"-[MachApp applicationDidFinishLaunching:]":
                \\    .cfi_startproc
                \\Lloh0:
                \\    adrp x0, __dispatch_main_q@GOTPAGE
                \\Lloh1:
                \\    ldr x0, [x0, __dispatch_main_q@GOTPAGEOFF]
                \\Lloh2:
                \\    adrp x1, ___block_literal_global@PAGE
                \\Lloh3:
                \\    add x1, x1, ___block_literal_global@PAGEOFF
                \\    b _dispatch_async
                \\    .loh AdrpAdd Lloh2, Lloh3
                \\    .loh AdrpLdrGot Lloh0, Lloh1
                \\    .cfi_endproc
                \\
                \\    .p2align 2
                \\"___41-[MachApp applicationDidFinishLaunching:]_block_invoke":
                \\    .cfi_startproc
                \\    b _machRun
                \\    .cfi_endproc
                \\
                \\    .section __TEXT,__cstring,cstring_literals
                \\l_.str:
                \\    .asciz "v8@?0"
                \\
                \\    .private_extern "___block_descriptor_32_e5_v8\x01?0l"
                \\    .section __DATA,__const
                \\    .globl "___block_descriptor_32_e5_v8\x01?0l"
                \\    .weak_def_can_be_hidden "___block_descriptor_32_e5_v8\x01?0l"
                \\    .p2align 3, 0x0
                \\"___block_descriptor_32_e5_v8\x01?0l":
                \\    .quad 0
                \\    .quad 32
                \\    .quad l_.str
                \\    .quad 0
                \\
                \\    .p2align 3, 0x0
                \\___block_literal_global:
                \\    .quad __NSConcreteGlobalBlock
                \\    .long 1342177280
                \\    .long 0
                \\    .quad "___41-[MachApp applicationDidFinishLaunching:]_block_invoke"
                \\    .quad "___block_descriptor_32_e5_v8\x01?0l"
                \\
                \\    .section __TEXT,__objc_classname,cstring_literals
                \\l_OBJC_CLASS_NAME_:
                \\    .asciz "MachApp"
                \\
                \\l_OBJC_CLASS_NAME_.1:
                \\    .asciz "NSApplicationDelegate"
                \\
                \\l_OBJC_CLASS_NAME_.2:
                \\    .asciz "NSObject"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\l_OBJC_METH_VAR_NAME_:
                \\    .asciz "isEqual:"
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\l_OBJC_METH_VAR_TYPE_:
                \\    .asciz "B24@0:8@16"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\l_OBJC_METH_VAR_NAME_.3:
                \\    .asciz "class"
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\l_OBJC_METH_VAR_TYPE_.4:
                \\    .asciz "#16@0:8"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\l_OBJC_METH_VAR_NAME_.5:
                \\    .asciz "self"
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\l_OBJC_METH_VAR_TYPE_.6:
                \\    .asciz "@16@0:8"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\l_OBJC_METH_VAR_NAME_.7:
                \\    .asciz "performSelector:"
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\l_OBJC_METH_VAR_TYPE_.8:
                \\    .asciz "@24@0:8:16"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\l_OBJC_METH_VAR_NAME_.9:
                \\    .asciz "performSelector:withObject:"
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\l_OBJC_METH_VAR_TYPE_.10:
                \\    .asciz "@32@0:8:16@24"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\l_OBJC_METH_VAR_NAME_.11:
                \\    .asciz "performSelector:withObject:withObject:"
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\l_OBJC_METH_VAR_TYPE_.12:
                \\    .asciz "@40@0:8:16@24@32"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\l_OBJC_METH_VAR_NAME_.13:
                \\    .asciz "isProxy"
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\l_OBJC_METH_VAR_TYPE_.14:
                \\    .asciz "B16@0:8"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\l_OBJC_METH_VAR_NAME_.15:
                \\    .asciz "isKindOfClass:"
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\l_OBJC_METH_VAR_TYPE_.16:
                \\    .asciz "B24@0:8#16"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\l_OBJC_METH_VAR_NAME_.17:
                \\    .asciz "isMemberOfClass:"
                \\
                \\l_OBJC_METH_VAR_NAME_.18:
                \\    .asciz "conformsToProtocol:"
                \\
                \\l_OBJC_METH_VAR_NAME_.19:
                \\    .asciz "respondsToSelector:"
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\l_OBJC_METH_VAR_TYPE_.20:
                \\    .asciz "B24@0:8:16"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\l_OBJC_METH_VAR_NAME_.21:
                \\    .asciz "retain"
                \\
                \\l_OBJC_METH_VAR_NAME_.22:
                \\    .asciz "release"
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\l_OBJC_METH_VAR_TYPE_.23:
                \\    .asciz "Vv16@0:8"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\l_OBJC_METH_VAR_NAME_.24:
                \\    .asciz "autorelease"
                \\
                \\l_OBJC_METH_VAR_NAME_.25:
                \\    .asciz "retainCount"
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\l_OBJC_METH_VAR_TYPE_.26:
                \\    .asciz "Q16@0:8"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\l_OBJC_METH_VAR_NAME_.27:
                \\    .asciz "zone"
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\l_OBJC_METH_VAR_TYPE_.28:
                \\    .asciz "^{_NSZone=}16@0:8"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\l_OBJC_METH_VAR_NAME_.29:
                \\    .asciz "hash"
                \\
                \\l_OBJC_METH_VAR_NAME_.30:
                \\    .asciz "superclass"
                \\
                \\l_OBJC_METH_VAR_NAME_.31:
                \\    .asciz "description"
                \\
                \\    .section __DATA,__objc_const
                \\    .p2align 3, 0x0
                \\__OBJC_$_PROTOCOL_INSTANCE_METHODS_NSObject:
                \\    .long 24
                \\    .long 19
                \\    .quad l_OBJC_METH_VAR_NAME_
                \\    .quad l_OBJC_METH_VAR_TYPE_
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.3
                \\    .quad l_OBJC_METH_VAR_TYPE_.4
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.5
                \\    .quad l_OBJC_METH_VAR_TYPE_.6
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.7
                \\    .quad l_OBJC_METH_VAR_TYPE_.8
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.9
                \\    .quad l_OBJC_METH_VAR_TYPE_.10
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.11
                \\    .quad l_OBJC_METH_VAR_TYPE_.12
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.13
                \\    .quad l_OBJC_METH_VAR_TYPE_.14
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.15
                \\    .quad l_OBJC_METH_VAR_TYPE_.16
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.17
                \\    .quad l_OBJC_METH_VAR_TYPE_.16
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.18
                \\    .quad l_OBJC_METH_VAR_TYPE_
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.19
                \\    .quad l_OBJC_METH_VAR_TYPE_.20
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.21
                \\    .quad l_OBJC_METH_VAR_TYPE_.6
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.22
                \\    .quad l_OBJC_METH_VAR_TYPE_.23
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.24
                \\    .quad l_OBJC_METH_VAR_TYPE_.6
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.25
                \\    .quad l_OBJC_METH_VAR_TYPE_.26
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.27
                \\    .quad l_OBJC_METH_VAR_TYPE_.28
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.29
                \\    .quad l_OBJC_METH_VAR_TYPE_.26
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.30
                \\    .quad l_OBJC_METH_VAR_TYPE_.4
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.31
                \\    .quad l_OBJC_METH_VAR_TYPE_.6
                \\    .quad 0
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\l_OBJC_METH_VAR_NAME_.32:
                \\    .asciz "debugDescription"
                \\
                \\    .section __DATA,__objc_const
                \\    .p2align 3, 0x0
                \\__OBJC_$_PROTOCOL_INSTANCE_METHODS_OPT_NSObject:
                \\    .long 24
                \\    .long 1
                \\    .quad l_OBJC_METH_VAR_NAME_.32
                \\    .quad l_OBJC_METH_VAR_TYPE_.6
                \\    .quad 0
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\l_OBJC_PROP_NAME_ATTR_:
                \\    .asciz "hash"
                \\
                \\l_OBJC_PROP_NAME_ATTR_.33:
                \\    .asciz "TQ,R"
                \\
                \\l_OBJC_PROP_NAME_ATTR_.34:
                \\    .asciz "superclass"
                \\
                \\l_OBJC_PROP_NAME_ATTR_.35:
                \\    .asciz "T#,R"
                \\
                \\l_OBJC_PROP_NAME_ATTR_.36:
                \\    .asciz "description"
                \\
                \\l_OBJC_PROP_NAME_ATTR_.37:
                \\    .asciz "T@\"NSString\",R,C"
                \\
                \\l_OBJC_PROP_NAME_ATTR_.38:
                \\    .asciz "debugDescription"
                \\
                \\l_OBJC_PROP_NAME_ATTR_.39:
                \\    .asciz "T@\"NSString\",?,R,C"
                \\
                \\    .section __DATA,__objc_const
                \\    .p2align 3, 0x0
                \\__OBJC_$_PROP_LIST_NSObject:
                \\    .long 16
                \\    .long 4
                \\    .quad l_OBJC_PROP_NAME_ATTR_
                \\    .quad l_OBJC_PROP_NAME_ATTR_.33
                \\    .quad l_OBJC_PROP_NAME_ATTR_.34
                \\    .quad l_OBJC_PROP_NAME_ATTR_.35
                \\    .quad l_OBJC_PROP_NAME_ATTR_.36
                \\    .quad l_OBJC_PROP_NAME_ATTR_.37
                \\    .quad l_OBJC_PROP_NAME_ATTR_.38
                \\    .quad l_OBJC_PROP_NAME_ATTR_.39
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\l_OBJC_METH_VAR_TYPE_.40:
                \\    .asciz "B24@0:8@\"Protocol\"16"
                \\
                \\l_OBJC_METH_VAR_TYPE_.41:
                \\    .asciz "@\"NSString\"16@0:8"
                \\
                \\    .section __DATA,__objc_const
                \\    .p2align 3, 0x0
                \\__OBJC_$_PROTOCOL_METHOD_TYPES_NSObject:
                \\    .quad l_OBJC_METH_VAR_TYPE_
                \\    .quad l_OBJC_METH_VAR_TYPE_.4
                \\    .quad l_OBJC_METH_VAR_TYPE_.6
                \\    .quad l_OBJC_METH_VAR_TYPE_.8
                \\    .quad l_OBJC_METH_VAR_TYPE_.10
                \\    .quad l_OBJC_METH_VAR_TYPE_.12
                \\    .quad l_OBJC_METH_VAR_TYPE_.14
                \\    .quad l_OBJC_METH_VAR_TYPE_.16
                \\    .quad l_OBJC_METH_VAR_TYPE_.16
                \\    .quad l_OBJC_METH_VAR_TYPE_.40
                \\    .quad l_OBJC_METH_VAR_TYPE_.20
                \\    .quad l_OBJC_METH_VAR_TYPE_.6
                \\    .quad l_OBJC_METH_VAR_TYPE_.23
                \\    .quad l_OBJC_METH_VAR_TYPE_.6
                \\    .quad l_OBJC_METH_VAR_TYPE_.26
                \\    .quad l_OBJC_METH_VAR_TYPE_.28
                \\    .quad l_OBJC_METH_VAR_TYPE_.26
                \\    .quad l_OBJC_METH_VAR_TYPE_.4
                \\    .quad l_OBJC_METH_VAR_TYPE_.41
                \\    .quad l_OBJC_METH_VAR_TYPE_.41
                \\
                \\    .private_extern __OBJC_PROTOCOL_$_NSObject
                \\    .section __DATA,__data
                \\    .globl __OBJC_PROTOCOL_$_NSObject
                \\    .weak_definition __OBJC_PROTOCOL_$_NSObject
                \\    .p2align 3, 0x0
                \\__OBJC_PROTOCOL_$_NSObject:
                \\    .quad 0
                \\    .quad l_OBJC_CLASS_NAME_.2
                \\    .quad 0
                \\    .quad __OBJC_$_PROTOCOL_INSTANCE_METHODS_NSObject
                \\    .quad 0
                \\    .quad __OBJC_$_PROTOCOL_INSTANCE_METHODS_OPT_NSObject
                \\    .quad 0
                \\    .quad __OBJC_$_PROP_LIST_NSObject
                \\    .long 96
                \\    .long 0
                \\    .quad __OBJC_$_PROTOCOL_METHOD_TYPES_NSObject
                \\    .quad 0
                \\    .quad 0
                \\
                \\    .private_extern __OBJC_LABEL_PROTOCOL_$_NSObject
                \\    .section __DATA,__objc_protolist,coalesced,no_dead_strip
                \\    .globl __OBJC_LABEL_PROTOCOL_$_NSObject
                \\    .weak_definition __OBJC_LABEL_PROTOCOL_$_NSObject
                \\    .p2align 3, 0x0
                \\__OBJC_LABEL_PROTOCOL_$_NSObject:
                \\    .quad __OBJC_PROTOCOL_$_NSObject
                \\
                \\    .section __DATA,__objc_const
                \\    .p2align 3, 0x0
                \\__OBJC_$_PROTOCOL_REFS_NSApplicationDelegate:
                \\    .quad 1
                \\    .quad __OBJC_PROTOCOL_$_NSObject
                \\    .quad 0
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\l_OBJC_METH_VAR_NAME_.42:
                \\    .asciz "applicationShouldTerminate:"
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\l_OBJC_METH_VAR_TYPE_.43:
                \\    .asciz "Q24@0:8@16"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\l_OBJC_METH_VAR_NAME_.44:
                \\    .asciz "application:openURLs:"
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\l_OBJC_METH_VAR_TYPE_.45:
                \\    .asciz "v32@0:8@16@24"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\l_OBJC_METH_VAR_NAME_.46:
                \\    .asciz "application:openFile:"
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\l_OBJC_METH_VAR_TYPE_.47:
                \\    .asciz "B32@0:8@16@24"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\l_OBJC_METH_VAR_NAME_.48:
                \\    .asciz "application:openFiles:"
                \\
                \\l_OBJC_METH_VAR_NAME_.49:
                \\    .asciz "application:openTempFile:"
                \\
                \\l_OBJC_METH_VAR_NAME_.50:
                \\    .asciz "applicationShouldOpenUntitledFile:"
                \\
                \\l_OBJC_METH_VAR_NAME_.51:
                \\    .asciz "applicationOpenUntitledFile:"
                \\
                \\l_OBJC_METH_VAR_NAME_.52:
                \\    .asciz "application:openFileWithoutUI:"
                \\
                \\l_OBJC_METH_VAR_NAME_.53:
                \\    .asciz "application:printFile:"
                \\
                \\l_OBJC_METH_VAR_NAME_.54:
                \\    .asciz "application:printFiles:withSettings:showPrintPanels:"
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\l_OBJC_METH_VAR_TYPE_.55:
                \\    .asciz "Q44@0:8@16@24@32B40"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\l_OBJC_METH_VAR_NAME_.56:
                \\    .asciz "applicationShouldTerminateAfterLastWindowClosed:"
                \\
                \\l_OBJC_METH_VAR_NAME_.57:
                \\    .asciz "applicationShouldHandleReopen:hasVisibleWindows:"
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\l_OBJC_METH_VAR_TYPE_.58:
                \\    .asciz "B28@0:8@16B24"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\l_OBJC_METH_VAR_NAME_.59:
                \\    .asciz "applicationDockMenu:"
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\l_OBJC_METH_VAR_TYPE_.60:
                \\    .asciz "@24@0:8@16"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\l_OBJC_METH_VAR_NAME_.61:
                \\    .asciz "application:willPresentError:"
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\l_OBJC_METH_VAR_TYPE_.62:
                \\    .asciz "@32@0:8@16@24"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\l_OBJC_METH_VAR_NAME_.63:
                \\    .asciz "application:didRegisterForRemoteNotificationsWithDeviceToken:"
                \\
                \\l_OBJC_METH_VAR_NAME_.64:
                \\    .asciz "application:didFailToRegisterForRemoteNotificationsWithError:"
                \\
                \\l_OBJC_METH_VAR_NAME_.65:
                \\    .asciz "application:didReceiveRemoteNotification:"
                \\
                \\l_OBJC_METH_VAR_NAME_.66:
                \\    .asciz "applicationSupportsSecureRestorableState:"
                \\
                \\l_OBJC_METH_VAR_NAME_.67:
                \\    .asciz "application:handlerForIntent:"
                \\
                \\l_OBJC_METH_VAR_NAME_.68:
                \\    .asciz "application:willEncodeRestorableState:"
                \\
                \\l_OBJC_METH_VAR_NAME_.69:
                \\    .asciz "application:didDecodeRestorableState:"
                \\
                \\l_OBJC_METH_VAR_NAME_.70:
                \\    .asciz "application:willContinueUserActivityWithType:"
                \\
                \\l_OBJC_METH_VAR_NAME_.71:
                \\    .asciz "application:continueUserActivity:restorationHandler:"
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\l_OBJC_METH_VAR_TYPE_.72:
                \\    .asciz "B40@0:8@16@24@?32"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\l_OBJC_METH_VAR_NAME_.73:
                \\    .asciz "application:didFailToContinueUserActivityWithType:error:"
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\l_OBJC_METH_VAR_TYPE_.74:
                \\    .asciz "v40@0:8@16@24@32"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\l_OBJC_METH_VAR_NAME_.75:
                \\    .asciz "application:didUpdateUserActivity:"
                \\
                \\l_OBJC_METH_VAR_NAME_.76:
                \\    .asciz "application:userDidAcceptCloudKitShareWithMetadata:"
                \\
                \\l_OBJC_METH_VAR_NAME_.77:
                \\    .asciz "application:delegateHandlesKey:"
                \\
                \\l_OBJC_METH_VAR_NAME_.78:
                \\    .asciz "applicationShouldAutomaticallyLocalizeKeyEquivalents:"
                \\
                \\l_OBJC_METH_VAR_NAME_.79:
                \\    .asciz "applicationWillFinishLaunching:"
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\l_OBJC_METH_VAR_TYPE_.80:
                \\    .asciz "v24@0:8@16"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\l_OBJC_METH_VAR_NAME_.81:
                \\    .asciz "applicationDidFinishLaunching:"
                \\
                \\l_OBJC_METH_VAR_NAME_.82:
                \\    .asciz "applicationWillHide:"
                \\
                \\l_OBJC_METH_VAR_NAME_.83:
                \\    .asciz "applicationDidHide:"
                \\
                \\l_OBJC_METH_VAR_NAME_.84:
                \\    .asciz "applicationWillUnhide:"
                \\
                \\l_OBJC_METH_VAR_NAME_.85:
                \\    .asciz "applicationDidUnhide:"
                \\
                \\l_OBJC_METH_VAR_NAME_.86:
                \\    .asciz "applicationWillBecomeActive:"
                \\
                \\l_OBJC_METH_VAR_NAME_.87:
                \\    .asciz "applicationDidBecomeActive:"
                \\
                \\l_OBJC_METH_VAR_NAME_.88:
                \\    .asciz "applicationWillResignActive:"
                \\
                \\l_OBJC_METH_VAR_NAME_.89:
                \\    .asciz "applicationDidResignActive:"
                \\
                \\l_OBJC_METH_VAR_NAME_.90:
                \\    .asciz "applicationWillUpdate:"
                \\
                \\l_OBJC_METH_VAR_NAME_.91:
                \\    .asciz "applicationDidUpdate:"
                \\
                \\l_OBJC_METH_VAR_NAME_.92:
                \\    .asciz "applicationWillTerminate:"
                \\
                \\l_OBJC_METH_VAR_NAME_.93:
                \\    .asciz "applicationDidChangeScreenParameters:"
                \\
                \\l_OBJC_METH_VAR_NAME_.94:
                \\    .asciz "applicationDidChangeOcclusionState:"
                \\
                \\l_OBJC_METH_VAR_NAME_.95:
                \\    .asciz "applicationProtectedDataWillBecomeUnavailable:"
                \\
                \\l_OBJC_METH_VAR_NAME_.96:
                \\    .asciz "applicationProtectedDataDidBecomeAvailable:"
                \\
                \\    .section __DATA,__objc_const
                \\    .p2align 3, 0x0
                \\__OBJC_$_PROTOCOL_INSTANCE_METHODS_OPT_NSApplicationDelegate:
                \\    .long 24
                \\    .long 45
                \\    .quad l_OBJC_METH_VAR_NAME_.42
                \\    .quad l_OBJC_METH_VAR_TYPE_.43
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.44
                \\    .quad l_OBJC_METH_VAR_TYPE_.45
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.46
                \\    .quad l_OBJC_METH_VAR_TYPE_.47
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.48
                \\    .quad l_OBJC_METH_VAR_TYPE_.45
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.49
                \\    .quad l_OBJC_METH_VAR_TYPE_.47
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.50
                \\    .quad l_OBJC_METH_VAR_TYPE_
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.51
                \\    .quad l_OBJC_METH_VAR_TYPE_
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.52
                \\    .quad l_OBJC_METH_VAR_TYPE_.47
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.53
                \\    .quad l_OBJC_METH_VAR_TYPE_.47
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.54
                \\    .quad l_OBJC_METH_VAR_TYPE_.55
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.56
                \\    .quad l_OBJC_METH_VAR_TYPE_
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.57
                \\    .quad l_OBJC_METH_VAR_TYPE_.58
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.59
                \\    .quad l_OBJC_METH_VAR_TYPE_.60
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.61
                \\    .quad l_OBJC_METH_VAR_TYPE_.62
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.63
                \\    .quad l_OBJC_METH_VAR_TYPE_.45
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.64
                \\    .quad l_OBJC_METH_VAR_TYPE_.45
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.65
                \\    .quad l_OBJC_METH_VAR_TYPE_.45
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.66
                \\    .quad l_OBJC_METH_VAR_TYPE_
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.67
                \\    .quad l_OBJC_METH_VAR_TYPE_.62
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.68
                \\    .quad l_OBJC_METH_VAR_TYPE_.45
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.69
                \\    .quad l_OBJC_METH_VAR_TYPE_.45
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.70
                \\    .quad l_OBJC_METH_VAR_TYPE_.47
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.71
                \\    .quad l_OBJC_METH_VAR_TYPE_.72
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.73
                \\    .quad l_OBJC_METH_VAR_TYPE_.74
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.75
                \\    .quad l_OBJC_METH_VAR_TYPE_.45
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.76
                \\    .quad l_OBJC_METH_VAR_TYPE_.45
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.77
                \\    .quad l_OBJC_METH_VAR_TYPE_.47
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.78
                \\    .quad l_OBJC_METH_VAR_TYPE_
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.79
                \\    .quad l_OBJC_METH_VAR_TYPE_.80
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.81
                \\    .quad l_OBJC_METH_VAR_TYPE_.80
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.82
                \\    .quad l_OBJC_METH_VAR_TYPE_.80
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.83
                \\    .quad l_OBJC_METH_VAR_TYPE_.80
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.84
                \\    .quad l_OBJC_METH_VAR_TYPE_.80
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.85
                \\    .quad l_OBJC_METH_VAR_TYPE_.80
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.86
                \\    .quad l_OBJC_METH_VAR_TYPE_.80
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.87
                \\    .quad l_OBJC_METH_VAR_TYPE_.80
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.88
                \\    .quad l_OBJC_METH_VAR_TYPE_.80
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.89
                \\    .quad l_OBJC_METH_VAR_TYPE_.80
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.90
                \\    .quad l_OBJC_METH_VAR_TYPE_.80
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.91
                \\    .quad l_OBJC_METH_VAR_TYPE_.80
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.92
                \\    .quad l_OBJC_METH_VAR_TYPE_.80
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.93
                \\    .quad l_OBJC_METH_VAR_TYPE_.80
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.94
                \\    .quad l_OBJC_METH_VAR_TYPE_.80
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.95
                \\    .quad l_OBJC_METH_VAR_TYPE_.80
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.96
                \\    .quad l_OBJC_METH_VAR_TYPE_.80
                \\    .quad 0
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\l_OBJC_METH_VAR_TYPE_.97:
                \\    .asciz "Q24@0:8@\"NSApplication\"16"
                \\
                \\l_OBJC_METH_VAR_TYPE_.98:
                \\    .asciz "v32@0:8@\"NSApplication\"16@\"NSArray\"24"
                \\
                \\l_OBJC_METH_VAR_TYPE_.99:
                \\    .asciz "B32@0:8@\"NSApplication\"16@\"NSString\"24"
                \\
                \\l_OBJC_METH_VAR_TYPE_.100:
                \\    .asciz "B24@0:8@\"NSApplication\"16"
                \\
                \\l_OBJC_METH_VAR_TYPE_.101:
                \\    .asciz "B32@0:8@16@\"NSString\"24"
                \\
                \\l_OBJC_METH_VAR_TYPE_.102:
                \\    .asciz "Q44@0:8@\"NSApplication\"16@\"NSArray\"24@\"NSDictionary\"32B40"
                \\
                \\l_OBJC_METH_VAR_TYPE_.103:
                \\    .asciz "B28@0:8@\"NSApplication\"16B24"
                \\
                \\l_OBJC_METH_VAR_TYPE_.104:
                \\    .asciz "@\"NSMenu\"24@0:8@\"NSApplication\"16"
                \\
                \\l_OBJC_METH_VAR_TYPE_.105:
                \\    .asciz "@\"NSError\"32@0:8@\"NSApplication\"16@\"NSError\"24"
                \\
                \\l_OBJC_METH_VAR_TYPE_.106:
                \\    .asciz "v32@0:8@\"NSApplication\"16@\"NSData\"24"
                \\
                \\l_OBJC_METH_VAR_TYPE_.107:
                \\    .asciz "v32@0:8@\"NSApplication\"16@\"NSError\"24"
                \\
                \\l_OBJC_METH_VAR_TYPE_.108:
                \\    .asciz "v32@0:8@\"NSApplication\"16@\"NSDictionary\"24"
                \\
                \\l_OBJC_METH_VAR_TYPE_.109:
                \\    .asciz "@32@0:8@\"NSApplication\"16@\"INIntent\"24"
                \\
                \\l_OBJC_METH_VAR_TYPE_.110:
                \\    .asciz "v32@0:8@\"NSApplication\"16@\"NSCoder\"24"
                \\
                \\l_OBJC_METH_VAR_TYPE_.111:
                \\    .asciz "B40@0:8@\"NSApplication\"16@\"NSUserActivity\"24@?<v@?@\"NSArray\">32"
                \\
                \\l_OBJC_METH_VAR_TYPE_.112:
                \\    .asciz "v40@0:8@\"NSApplication\"16@\"NSString\"24@\"NSError\"32"
                \\
                \\l_OBJC_METH_VAR_TYPE_.113:
                \\    .asciz "v32@0:8@\"NSApplication\"16@\"NSUserActivity\"24"
                \\
                \\l_OBJC_METH_VAR_TYPE_.114:
                \\    .asciz "v32@0:8@\"NSApplication\"16@\"CKShareMetadata\"24"
                \\
                \\l_OBJC_METH_VAR_TYPE_.115:
                \\    .asciz "v24@0:8@\"NSNotification\"16"
                \\
                \\    .section __DATA,__objc_const
                \\    .p2align 3, 0x0
                \\__OBJC_$_PROTOCOL_METHOD_TYPES_NSApplicationDelegate:
                \\    .quad l_OBJC_METH_VAR_TYPE_.97
                \\    .quad l_OBJC_METH_VAR_TYPE_.98
                \\    .quad l_OBJC_METH_VAR_TYPE_.99
                \\    .quad l_OBJC_METH_VAR_TYPE_.98
                \\    .quad l_OBJC_METH_VAR_TYPE_.99
                \\    .quad l_OBJC_METH_VAR_TYPE_.100
                \\    .quad l_OBJC_METH_VAR_TYPE_.100
                \\    .quad l_OBJC_METH_VAR_TYPE_.101
                \\    .quad l_OBJC_METH_VAR_TYPE_.99
                \\    .quad l_OBJC_METH_VAR_TYPE_.102
                \\    .quad l_OBJC_METH_VAR_TYPE_.100
                \\    .quad l_OBJC_METH_VAR_TYPE_.103
                \\    .quad l_OBJC_METH_VAR_TYPE_.104
                \\    .quad l_OBJC_METH_VAR_TYPE_.105
                \\    .quad l_OBJC_METH_VAR_TYPE_.106
                \\    .quad l_OBJC_METH_VAR_TYPE_.107
                \\    .quad l_OBJC_METH_VAR_TYPE_.108
                \\    .quad l_OBJC_METH_VAR_TYPE_.100
                \\    .quad l_OBJC_METH_VAR_TYPE_.109
                \\    .quad l_OBJC_METH_VAR_TYPE_.110
                \\    .quad l_OBJC_METH_VAR_TYPE_.110
                \\    .quad l_OBJC_METH_VAR_TYPE_.99
                \\    .quad l_OBJC_METH_VAR_TYPE_.111
                \\    .quad l_OBJC_METH_VAR_TYPE_.112
                \\    .quad l_OBJC_METH_VAR_TYPE_.113
                \\    .quad l_OBJC_METH_VAR_TYPE_.114
                \\    .quad l_OBJC_METH_VAR_TYPE_.99
                \\    .quad l_OBJC_METH_VAR_TYPE_.100
                \\    .quad l_OBJC_METH_VAR_TYPE_.115
                \\    .quad l_OBJC_METH_VAR_TYPE_.115
                \\    .quad l_OBJC_METH_VAR_TYPE_.115
                \\    .quad l_OBJC_METH_VAR_TYPE_.115
                \\    .quad l_OBJC_METH_VAR_TYPE_.115
                \\    .quad l_OBJC_METH_VAR_TYPE_.115
                \\    .quad l_OBJC_METH_VAR_TYPE_.115
                \\    .quad l_OBJC_METH_VAR_TYPE_.115
                \\    .quad l_OBJC_METH_VAR_TYPE_.115
                \\    .quad l_OBJC_METH_VAR_TYPE_.115
                \\    .quad l_OBJC_METH_VAR_TYPE_.115
                \\    .quad l_OBJC_METH_VAR_TYPE_.115
                \\    .quad l_OBJC_METH_VAR_TYPE_.115
                \\    .quad l_OBJC_METH_VAR_TYPE_.115
                \\    .quad l_OBJC_METH_VAR_TYPE_.115
                \\    .quad l_OBJC_METH_VAR_TYPE_.115
                \\    .quad l_OBJC_METH_VAR_TYPE_.115
                \\
                \\    .private_extern __OBJC_PROTOCOL_$_NSApplicationDelegate
                \\    .section __DATA,__data
                \\    .globl __OBJC_PROTOCOL_$_NSApplicationDelegate
                \\    .weak_definition __OBJC_PROTOCOL_$_NSApplicationDelegate
                \\    .p2align 3, 0x0
                \\__OBJC_PROTOCOL_$_NSApplicationDelegate:
                \\    .quad 0
                \\    .quad l_OBJC_CLASS_NAME_.1
                \\    .quad __OBJC_$_PROTOCOL_REFS_NSApplicationDelegate
                \\    .quad 0
                \\    .quad 0
                \\    .quad __OBJC_$_PROTOCOL_INSTANCE_METHODS_OPT_NSApplicationDelegate
                \\    .quad 0
                \\    .quad 0
                \\    .long 96
                \\    .long 0
                \\    .quad __OBJC_$_PROTOCOL_METHOD_TYPES_NSApplicationDelegate
                \\    .quad 0
                \\    .quad 0
                \\
                \\    .private_extern __OBJC_LABEL_PROTOCOL_$_NSApplicationDelegate
                \\    .section __DATA,__objc_protolist,coalesced,no_dead_strip
                \\    .globl __OBJC_LABEL_PROTOCOL_$_NSApplicationDelegate
                \\    .weak_definition __OBJC_LABEL_PROTOCOL_$_NSApplicationDelegate
                \\    .p2align 3, 0x0
                \\__OBJC_LABEL_PROTOCOL_$_NSApplicationDelegate:
                \\    .quad __OBJC_PROTOCOL_$_NSApplicationDelegate
                \\
                \\    .section __DATA,__objc_const
                \\    .p2align 3, 0x0
                \\__OBJC_CLASS_PROTOCOLS_$_MachApp:
                \\    .quad 1
                \\    .quad __OBJC_PROTOCOL_$_NSApplicationDelegate
                \\    .quad 0
                \\
                \\    .p2align 3, 0x0
                \\__OBJC_METACLASS_RO_$_MachApp:
                \\    .long 129
                \\    .long 40
                \\    .long 40
                \\    .space 4
                \\    .quad 0
                \\    .quad l_OBJC_CLASS_NAME_
                \\    .quad 0
                \\    .quad __OBJC_CLASS_PROTOCOLS_$_MachApp
                \\    .quad 0
                \\    .quad 0
                \\    .quad 0
                \\
                \\    .section __DATA,__objc_data
                \\    .globl _OBJC_METACLASS_$_MachApp
                \\    .p2align 3, 0x0
                \\_OBJC_METACLASS_$_MachApp:
                \\    .quad _OBJC_METACLASS_$_NSObject
                \\    .quad _OBJC_METACLASS_$_NSObject
                \\    .quad __objc_empty_cache
                \\    .quad 0
                \\    .quad __OBJC_METACLASS_RO_$_MachApp
                \\
                \\    .section __DATA,__objc_const
                \\    .p2align 3, 0x0
                \\__OBJC_$_INSTANCE_METHODS_MachApp:
                \\    .long 24
                \\    .long 1
                \\    .quad l_OBJC_METH_VAR_NAME_.81
                \\    .quad l_OBJC_METH_VAR_TYPE_.80
                \\    .quad "-[MachApp applicationDidFinishLaunching:]"
                \\
                \\    .p2align 3, 0x0
                \\__OBJC_$_PROP_LIST_MachApp:
                \\    .long 16
                \\    .long 4
                \\    .quad l_OBJC_PROP_NAME_ATTR_
                \\    .quad l_OBJC_PROP_NAME_ATTR_.33
                \\    .quad l_OBJC_PROP_NAME_ATTR_.34
                \\    .quad l_OBJC_PROP_NAME_ATTR_.35
                \\    .quad l_OBJC_PROP_NAME_ATTR_.36
                \\    .quad l_OBJC_PROP_NAME_ATTR_.37
                \\    .quad l_OBJC_PROP_NAME_ATTR_.38
                \\    .quad l_OBJC_PROP_NAME_ATTR_.39
                \\
                \\    .p2align 3, 0x0
                \\__OBJC_CLASS_RO_$_MachApp:
                \\    .long 128
                \\    .long 8
                \\    .long 8
                \\    .space 4
                \\    .quad 0
                \\    .quad l_OBJC_CLASS_NAME_
                \\    .quad __OBJC_$_INSTANCE_METHODS_MachApp
                \\    .quad __OBJC_CLASS_PROTOCOLS_$_MachApp
                \\    .quad 0
                \\    .quad 0
                \\    .quad __OBJC_$_PROP_LIST_MachApp
                \\
                \\    .section __DATA,__objc_data
                \\    .globl _OBJC_CLASS_$_MachApp
                \\    .p2align 3, 0x0
                \\_OBJC_CLASS_$_MachApp:
                \\    .quad _OBJC_METACLASS_$_MachApp
                \\    .quad _OBJC_CLASS_$_NSObject
                \\    .quad __objc_empty_cache
                \\    .quad 0
                \\    .quad __OBJC_CLASS_RO_$_MachApp
                \\
                \\    .section __DATA,__objc_classlist,regular,no_dead_strip
                \\    .p2align 3, 0x0
                \\l_OBJC_LABEL_CLASS_$:
                \\    .quad _OBJC_CLASS_$_MachApp
                \\
                \\    .no_dead_strip __OBJC_LABEL_PROTOCOL_$_NSApplicationDelegate
                \\    .no_dead_strip __OBJC_LABEL_PROTOCOL_$_NSObject
                \\    .no_dead_strip __OBJC_PROTOCOL_$_NSApplicationDelegate
                \\    .no_dead_strip __OBJC_PROTOCOL_$_NSObject
                \\    .section __DATA,__objc_imageinfo,regular,no_dead_strip
                \\L_OBJC_IMAGE_INFO:
                \\    .long 0
                \\    .long 64
                \\
                \\.subsections_via_symbols
            );
        } else {
            asm (
                \\    .section __TEXT,__text,regular,pure_instructions
                \\    .p2align 2
                \\"-[MachApp application:didFinishLaunchingWithOptions:]":
                \\    .cfi_startproc
                \\    stp x29, x30, [sp, #-16]!
                \\    .cfi_def_cfa_offset 16
                \\    .cfi_offset w30, -8
                \\    .cfi_offset w29, -16
                \\Lloh0:
                \\    adrp x0, __dispatch_main_q@GOTPAGE
                \\Lloh1:
                \\    ldr x0, [x0, __dispatch_main_q@GOTPAGEOFF]
                \\Lloh2:
                \\    adrp x1, ___block_literal_global@PAGE
                \\Lloh3:
                \\    add x1, x1, ___block_literal_global@PAGEOFF
                \\    bl _dispatch_async
                \\    mov w0, #1
                \\    ldp x29, x30, [sp], #16
                \\    ret
                \\    .loh AdrpAdd Lloh2, Lloh3
                \\    .loh AdrpLdrGot Lloh0, Lloh1
                \\    .cfi_endproc
                \\
                \\    .p2align 2
                \\"___53-[MachApp application:didFinishLaunchingWithOptions:]_block_invoke":
                \\    .cfi_startproc
                \\    b _machRun
                \\    .cfi_endproc
                \\
                \\    .section __TEXT,__cstring,cstring_literals
                \\l_.str:
                \\    .asciz "v8@?0"
                \\
                \\    .private_extern "___block_descriptor_32_e5_v8\x01?0l"
                \\    .section __DATA,__const
                \\    .globl "___block_descriptor_32_e5_v8\x01?0l"
                \\    .weak_def_can_be_hidden "___block_descriptor_32_e5_v8\x01?0l"
                \\    .p2align 3, 0x0
                \\"___block_descriptor_32_e5_v8\x01?0l":
                \\    .quad 0
                \\    .quad 32
                \\    .quad l_.str
                \\    .quad 0
                \\
                \\    .p2align 3, 0x0
                \\___block_literal_global:
                \\    .quad __NSConcreteGlobalBlock
                \\    .long 1342177280
                \\    .long 0
                \\    .quad "___53-[MachApp application:didFinishLaunchingWithOptions:]_block_invoke"
                \\    .quad "___block_descriptor_32_e5_v8\x01?0l"
                \\
                \\    .section __TEXT,__objc_classname,cstring_literals
                \\l_OBJC_CLASS_NAME_:
                \\    .asciz "MachApp"
                \\
                \\l_OBJC_CLASS_NAME_.1:
                \\    .asciz "UIApplicationDelegate"
                \\
                \\l_OBJC_CLASS_NAME_.2:
                \\    .asciz "NSObject"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\l_OBJC_METH_VAR_NAME_:
                \\    .asciz "isEqual:"
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\l_OBJC_METH_VAR_TYPE_:
                \\    .asciz "B24@0:8@16"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\l_OBJC_METH_VAR_NAME_.3:
                \\    .asciz "class"
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\l_OBJC_METH_VAR_TYPE_.4:
                \\    .asciz "#16@0:8"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\l_OBJC_METH_VAR_NAME_.5:
                \\    .asciz "self"
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\l_OBJC_METH_VAR_TYPE_.6:
                \\    .asciz "@16@0:8"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\l_OBJC_METH_VAR_NAME_.7:
                \\    .asciz "performSelector:"
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\l_OBJC_METH_VAR_TYPE_.8:
                \\    .asciz "@24@0:8:16"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\l_OBJC_METH_VAR_NAME_.9:
                \\    .asciz "performSelector:withObject:"
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\l_OBJC_METH_VAR_TYPE_.10:
                \\    .asciz "@32@0:8:16@24"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\l_OBJC_METH_VAR_NAME_.11:
                \\    .asciz "performSelector:withObject:withObject:"
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\l_OBJC_METH_VAR_TYPE_.12:
                \\    .asciz "@40@0:8:16@24@32"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\l_OBJC_METH_VAR_NAME_.13:
                \\    .asciz "isProxy"
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\l_OBJC_METH_VAR_TYPE_.14:
                \\    .asciz "B16@0:8"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\l_OBJC_METH_VAR_NAME_.15:
                \\    .asciz "isKindOfClass:"
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\l_OBJC_METH_VAR_TYPE_.16:
                \\    .asciz "B24@0:8#16"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\l_OBJC_METH_VAR_NAME_.17:
                \\    .asciz "isMemberOfClass:"
                \\
                \\l_OBJC_METH_VAR_NAME_.18:
                \\    .asciz "conformsToProtocol:"
                \\
                \\l_OBJC_METH_VAR_NAME_.19:
                \\    .asciz "respondsToSelector:"
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\l_OBJC_METH_VAR_TYPE_.20:
                \\    .asciz "B24@0:8:16"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\l_OBJC_METH_VAR_NAME_.21:
                \\    .asciz "retain"
                \\
                \\l_OBJC_METH_VAR_NAME_.22:
                \\    .asciz "release"
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\l_OBJC_METH_VAR_TYPE_.23:
                \\    .asciz "Vv16@0:8"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\l_OBJC_METH_VAR_NAME_.24:
                \\    .asciz "autorelease"
                \\
                \\l_OBJC_METH_VAR_NAME_.25:
                \\    .asciz "retainCount"
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\l_OBJC_METH_VAR_TYPE_.26:
                \\    .asciz "Q16@0:8"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\l_OBJC_METH_VAR_NAME_.27:
                \\    .asciz "zone"
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\l_OBJC_METH_VAR_TYPE_.28:
                \\    .asciz "^{_NSZone=}16@0:8"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\l_OBJC_METH_VAR_NAME_.29:
                \\    .asciz "hash"
                \\
                \\l_OBJC_METH_VAR_NAME_.30:
                \\    .asciz "superclass"
                \\
                \\l_OBJC_METH_VAR_NAME_.31:
                \\    .asciz "description"
                \\
                \\    .section __DATA,__objc_const
                \\    .p2align 3, 0x0
                \\__OBJC_$_PROTOCOL_INSTANCE_METHODS_NSObject:
                \\    .long 24
                \\    .long 19
                \\    .quad l_OBJC_METH_VAR_NAME_
                \\    .quad l_OBJC_METH_VAR_TYPE_
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.3
                \\    .quad l_OBJC_METH_VAR_TYPE_.4
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.5
                \\    .quad l_OBJC_METH_VAR_TYPE_.6
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.7
                \\    .quad l_OBJC_METH_VAR_TYPE_.8
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.9
                \\    .quad l_OBJC_METH_VAR_TYPE_.10
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.11
                \\    .quad l_OBJC_METH_VAR_TYPE_.12
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.13
                \\    .quad l_OBJC_METH_VAR_TYPE_.14
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.15
                \\    .quad l_OBJC_METH_VAR_TYPE_.16
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.17
                \\    .quad l_OBJC_METH_VAR_TYPE_.16
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.18
                \\    .quad l_OBJC_METH_VAR_TYPE_
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.19
                \\    .quad l_OBJC_METH_VAR_TYPE_.20
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.21
                \\    .quad l_OBJC_METH_VAR_TYPE_.6
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.22
                \\    .quad l_OBJC_METH_VAR_TYPE_.23
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.24
                \\    .quad l_OBJC_METH_VAR_TYPE_.6
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.25
                \\    .quad l_OBJC_METH_VAR_TYPE_.26
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.27
                \\    .quad l_OBJC_METH_VAR_TYPE_.28
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.29
                \\    .quad l_OBJC_METH_VAR_TYPE_.26
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.30
                \\    .quad l_OBJC_METH_VAR_TYPE_.4
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.31
                \\    .quad l_OBJC_METH_VAR_TYPE_.6
                \\    .quad 0
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\l_OBJC_METH_VAR_NAME_.32:
                \\    .asciz "debugDescription"
                \\
                \\    .section __DATA,__objc_const
                \\    .p2align 3, 0x0
                \\__OBJC_$_PROTOCOL_INSTANCE_METHODS_OPT_NSObject:
                \\    .long 24
                \\    .long 1
                \\    .quad l_OBJC_METH_VAR_NAME_.32
                \\    .quad l_OBJC_METH_VAR_TYPE_.6
                \\    .quad 0
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\l_OBJC_PROP_NAME_ATTR_:
                \\    .asciz "hash"
                \\
                \\l_OBJC_PROP_NAME_ATTR_.33:
                \\    .asciz "TQ,R"
                \\
                \\l_OBJC_PROP_NAME_ATTR_.34:
                \\    .asciz "superclass"
                \\
                \\l_OBJC_PROP_NAME_ATTR_.35:
                \\    .asciz "T#,R"
                \\
                \\l_OBJC_PROP_NAME_ATTR_.36:
                \\    .asciz "description"
                \\
                \\l_OBJC_PROP_NAME_ATTR_.37:
                \\    .asciz "T@\"NSString\",R,C"
                \\
                \\l_OBJC_PROP_NAME_ATTR_.38:
                \\    .asciz "debugDescription"
                \\
                \\l_OBJC_PROP_NAME_ATTR_.39:
                \\    .asciz "T@\"NSString\",?,R,C"
                \\
                \\    .section __DATA,__objc_const
                \\    .p2align 3, 0x0
                \\__OBJC_$_PROP_LIST_NSObject:
                \\    .long 16
                \\    .long 4
                \\    .quad l_OBJC_PROP_NAME_ATTR_
                \\    .quad l_OBJC_PROP_NAME_ATTR_.33
                \\    .quad l_OBJC_PROP_NAME_ATTR_.34
                \\    .quad l_OBJC_PROP_NAME_ATTR_.35
                \\    .quad l_OBJC_PROP_NAME_ATTR_.36
                \\    .quad l_OBJC_PROP_NAME_ATTR_.37
                \\    .quad l_OBJC_PROP_NAME_ATTR_.38
                \\    .quad l_OBJC_PROP_NAME_ATTR_.39
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\l_OBJC_METH_VAR_TYPE_.40:
                \\    .asciz "B24@0:8@\"Protocol\"16"
                \\
                \\l_OBJC_METH_VAR_TYPE_.41:
                \\    .asciz "@\"NSString\"16@0:8"
                \\
                \\    .section __DATA,__objc_const
                \\    .p2align 3, 0x0
                \\__OBJC_$_PROTOCOL_METHOD_TYPES_NSObject:
                \\    .quad l_OBJC_METH_VAR_TYPE_
                \\    .quad l_OBJC_METH_VAR_TYPE_.4
                \\    .quad l_OBJC_METH_VAR_TYPE_.6
                \\    .quad l_OBJC_METH_VAR_TYPE_.8
                \\    .quad l_OBJC_METH_VAR_TYPE_.10
                \\    .quad l_OBJC_METH_VAR_TYPE_.12
                \\    .quad l_OBJC_METH_VAR_TYPE_.14
                \\    .quad l_OBJC_METH_VAR_TYPE_.16
                \\    .quad l_OBJC_METH_VAR_TYPE_.16
                \\    .quad l_OBJC_METH_VAR_TYPE_.40
                \\    .quad l_OBJC_METH_VAR_TYPE_.20
                \\    .quad l_OBJC_METH_VAR_TYPE_.6
                \\    .quad l_OBJC_METH_VAR_TYPE_.23
                \\    .quad l_OBJC_METH_VAR_TYPE_.6
                \\    .quad l_OBJC_METH_VAR_TYPE_.26
                \\    .quad l_OBJC_METH_VAR_TYPE_.28
                \\    .quad l_OBJC_METH_VAR_TYPE_.26
                \\    .quad l_OBJC_METH_VAR_TYPE_.4
                \\    .quad l_OBJC_METH_VAR_TYPE_.41
                \\    .quad l_OBJC_METH_VAR_TYPE_.41
                \\
                \\    .private_extern __OBJC_PROTOCOL_$_NSObject
                \\    .section __DATA,__data
                \\    .globl __OBJC_PROTOCOL_$_NSObject
                \\    .weak_definition __OBJC_PROTOCOL_$_NSObject
                \\    .p2align 3, 0x0
                \\__OBJC_PROTOCOL_$_NSObject:
                \\    .quad 0
                \\    .quad l_OBJC_CLASS_NAME_.2
                \\    .quad 0
                \\    .quad __OBJC_$_PROTOCOL_INSTANCE_METHODS_NSObject
                \\    .quad 0
                \\    .quad __OBJC_$_PROTOCOL_INSTANCE_METHODS_OPT_NSObject
                \\    .quad 0
                \\    .quad __OBJC_$_PROP_LIST_NSObject
                \\    .long 96
                \\    .long 0
                \\    .quad __OBJC_$_PROTOCOL_METHOD_TYPES_NSObject
                \\    .quad 0
                \\    .quad 0
                \\
                \\    .private_extern __OBJC_LABEL_PROTOCOL_$_NSObject
                \\    .section __DATA,__objc_protolist,coalesced,no_dead_strip
                \\    .globl __OBJC_LABEL_PROTOCOL_$_NSObject
                \\    .weak_definition __OBJC_LABEL_PROTOCOL_$_NSObject
                \\    .p2align 3, 0x0
                \\__OBJC_LABEL_PROTOCOL_$_NSObject:
                \\    .quad __OBJC_PROTOCOL_$_NSObject
                \\
                \\    .section __DATA,__objc_const
                \\    .p2align 3, 0x0
                \\__OBJC_$_PROTOCOL_REFS_UIApplicationDelegate:
                \\    .quad 1
                \\    .quad __OBJC_PROTOCOL_$_NSObject
                \\    .quad 0
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\l_OBJC_METH_VAR_NAME_.42:
                \\    .asciz "applicationDidFinishLaunching:"
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\l_OBJC_METH_VAR_TYPE_.43:
                \\    .asciz "v24@0:8@16"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\l_OBJC_METH_VAR_NAME_.44:
                \\    .asciz "application:willFinishLaunchingWithOptions:"
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\l_OBJC_METH_VAR_TYPE_.45:
                \\    .asciz "B32@0:8@16@24"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\l_OBJC_METH_VAR_NAME_.46:
                \\    .asciz "application:didFinishLaunchingWithOptions:"
                \\
                \\l_OBJC_METH_VAR_NAME_.47:
                \\    .asciz "applicationDidBecomeActive:"
                \\
                \\l_OBJC_METH_VAR_NAME_.48:
                \\    .asciz "applicationWillResignActive:"
                \\
                \\l_OBJC_METH_VAR_NAME_.49:
                \\    .asciz "application:handleOpenURL:"
                \\
                \\l_OBJC_METH_VAR_NAME_.50:
                \\    .asciz "application:openURL:sourceApplication:annotation:"
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\l_OBJC_METH_VAR_TYPE_.51:
                \\    .asciz "B48@0:8@16@24@32@40"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\l_OBJC_METH_VAR_NAME_.52:
                \\    .asciz "application:openURL:options:"
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\l_OBJC_METH_VAR_TYPE_.53:
                \\    .asciz "B40@0:8@16@24@32"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\l_OBJC_METH_VAR_NAME_.54:
                \\    .asciz "applicationDidReceiveMemoryWarning:"
                \\
                \\l_OBJC_METH_VAR_NAME_.55:
                \\    .asciz "applicationWillTerminate:"
                \\
                \\l_OBJC_METH_VAR_NAME_.56:
                \\    .asciz "applicationSignificantTimeChange:"
                \\
                \\l_OBJC_METH_VAR_NAME_.57:
                \\    .asciz "application:willChangeStatusBarOrientation:duration:"
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\l_OBJC_METH_VAR_TYPE_.58:
                \\    .asciz "v40@0:8@16q24d32"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\l_OBJC_METH_VAR_NAME_.59:
                \\    .asciz "application:didChangeStatusBarOrientation:"
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\l_OBJC_METH_VAR_TYPE_.60:
                \\    .asciz "v32@0:8@16q24"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\l_OBJC_METH_VAR_NAME_.61:
                \\    .asciz "application:willChangeStatusBarFrame:"
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\l_OBJC_METH_VAR_TYPE_.62:
                \\    .asciz "v56@0:8@16{CGRect={CGPoint=dd}{CGSize=dd}}24"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\l_OBJC_METH_VAR_NAME_.63:
                \\    .asciz "application:didChangeStatusBarFrame:"
                \\
                \\l_OBJC_METH_VAR_NAME_.64:
                \\    .asciz "application:didRegisterUserNotificationSettings:"
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\l_OBJC_METH_VAR_TYPE_.65:
                \\    .asciz "v32@0:8@16@24"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\l_OBJC_METH_VAR_NAME_.66:
                \\    .asciz "application:didRegisterForRemoteNotificationsWithDeviceToken:"
                \\
                \\l_OBJC_METH_VAR_NAME_.67:
                \\    .asciz "application:didFailToRegisterForRemoteNotificationsWithError:"
                \\
                \\l_OBJC_METH_VAR_NAME_.68:
                \\    .asciz "application:didReceiveRemoteNotification:"
                \\
                \\l_OBJC_METH_VAR_NAME_.69:
                \\    .asciz "application:didReceiveLocalNotification:"
                \\
                \\l_OBJC_METH_VAR_NAME_.70:
                \\    .asciz "application:handleActionWithIdentifier:forLocalNotification:completionHandler:"
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\l_OBJC_METH_VAR_TYPE_.71:
                \\    .asciz "v48@0:8@16@24@32@?40"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\l_OBJC_METH_VAR_NAME_.72:
                \\    .asciz "application:handleActionWithIdentifier:forRemoteNotification:withResponseInfo:completionHandler:"
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\l_OBJC_METH_VAR_TYPE_.73:
                \\    .asciz "v56@0:8@16@24@32@40@?48"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\l_OBJC_METH_VAR_NAME_.74:
                \\    .asciz "application:handleActionWithIdentifier:forRemoteNotification:completionHandler:"
                \\
                \\l_OBJC_METH_VAR_NAME_.75:
                \\    .asciz "application:handleActionWithIdentifier:forLocalNotification:withResponseInfo:completionHandler:"
                \\
                \\l_OBJC_METH_VAR_NAME_.76:
                \\    .asciz "application:didReceiveRemoteNotification:fetchCompletionHandler:"
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\l_OBJC_METH_VAR_TYPE_.77:
                \\    .asciz "v40@0:8@16@24@?32"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\l_OBJC_METH_VAR_NAME_.78:
                \\    .asciz "application:performFetchWithCompletionHandler:"
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\l_OBJC_METH_VAR_TYPE_.79:
                \\    .asciz "v32@0:8@16@?24"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\l_OBJC_METH_VAR_NAME_.80:
                \\    .asciz "application:performActionForShortcutItem:completionHandler:"
                \\
                \\l_OBJC_METH_VAR_NAME_.81:
                \\    .asciz "application:handleEventsForBackgroundURLSession:completionHandler:"
                \\
                \\l_OBJC_METH_VAR_NAME_.82:
                \\    .asciz "application:handleWatchKitExtensionRequest:reply:"
                \\
                \\l_OBJC_METH_VAR_NAME_.83:
                \\    .asciz "applicationShouldRequestHealthAuthorization:"
                \\
                \\l_OBJC_METH_VAR_NAME_.84:
                \\    .asciz "application:handlerForIntent:"
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\l_OBJC_METH_VAR_TYPE_.85:
                \\    .asciz "@32@0:8@16@24"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\l_OBJC_METH_VAR_NAME_.86:
                \\    .asciz "application:handleIntent:completionHandler:"
                \\
                \\l_OBJC_METH_VAR_NAME_.87:
                \\    .asciz "applicationDidEnterBackground:"
                \\
                \\l_OBJC_METH_VAR_NAME_.88:
                \\    .asciz "applicationWillEnterForeground:"
                \\
                \\l_OBJC_METH_VAR_NAME_.89:
                \\    .asciz "applicationProtectedDataWillBecomeUnavailable:"
                \\
                \\l_OBJC_METH_VAR_NAME_.90:
                \\    .asciz "applicationProtectedDataDidBecomeAvailable:"
                \\
                \\l_OBJC_METH_VAR_NAME_.91:
                \\    .asciz "application:supportedInterfaceOrientationsForWindow:"
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\l_OBJC_METH_VAR_TYPE_.92:
                \\    .asciz "Q32@0:8@16@24"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\l_OBJC_METH_VAR_NAME_.93:
                \\    .asciz "application:shouldAllowExtensionPointIdentifier:"
                \\
                \\l_OBJC_METH_VAR_NAME_.94:
                \\    .asciz "application:viewControllerWithRestorationIdentifierPath:coder:"
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\l_OBJC_METH_VAR_TYPE_.95:
                \\    .asciz "@40@0:8@16@24@32"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\l_OBJC_METH_VAR_NAME_.96:
                \\    .asciz "application:shouldSaveSecureApplicationState:"
                \\
                \\l_OBJC_METH_VAR_NAME_.97:
                \\    .asciz "application:shouldRestoreSecureApplicationState:"
                \\
                \\l_OBJC_METH_VAR_NAME_.98:
                \\    .asciz "application:willEncodeRestorableStateWithCoder:"
                \\
                \\l_OBJC_METH_VAR_NAME_.99:
                \\    .asciz "application:didDecodeRestorableStateWithCoder:"
                \\
                \\l_OBJC_METH_VAR_NAME_.100:
                \\    .asciz "application:shouldSaveApplicationState:"
                \\
                \\l_OBJC_METH_VAR_NAME_.101:
                \\    .asciz "application:shouldRestoreApplicationState:"
                \\
                \\l_OBJC_METH_VAR_NAME_.102:
                \\    .asciz "application:willContinueUserActivityWithType:"
                \\
                \\l_OBJC_METH_VAR_NAME_.103:
                \\    .asciz "application:continueUserActivity:restorationHandler:"
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\l_OBJC_METH_VAR_TYPE_.104:
                \\    .asciz "B40@0:8@16@24@?32"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\l_OBJC_METH_VAR_NAME_.105:
                \\    .asciz "application:didFailToContinueUserActivityWithType:error:"
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\l_OBJC_METH_VAR_TYPE_.106:
                \\    .asciz "v40@0:8@16@24@32"
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\l_OBJC_METH_VAR_NAME_.107:
                \\    .asciz "application:didUpdateUserActivity:"
                \\
                \\l_OBJC_METH_VAR_NAME_.108:
                \\    .asciz "application:userDidAcceptCloudKitShareWithMetadata:"
                \\
                \\l_OBJC_METH_VAR_NAME_.109:
                \\    .asciz "application:configurationForConnectingSceneSession:options:"
                \\
                \\l_OBJC_METH_VAR_NAME_.110:
                \\    .asciz "application:didDiscardSceneSessions:"
                \\
                \\l_OBJC_METH_VAR_NAME_.111:
                \\    .asciz "applicationShouldAutomaticallyLocalizeKeyCommands:"
                \\
                \\l_OBJC_METH_VAR_NAME_.112:
                \\    .asciz "window"
                \\
                \\l_OBJC_METH_VAR_NAME_.113:
                \\    .asciz "setWindow:"
                \\
                \\    .section __DATA,__objc_const
                \\    .p2align 3, 0x0
                \\__OBJC_$_PROTOCOL_INSTANCE_METHODS_OPT_UIApplicationDelegate:
                \\    .long 24
                \\    .long 55
                \\    .quad l_OBJC_METH_VAR_NAME_.42
                \\    .quad l_OBJC_METH_VAR_TYPE_.43
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.44
                \\    .quad l_OBJC_METH_VAR_TYPE_.45
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.46
                \\    .quad l_OBJC_METH_VAR_TYPE_.45
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.47
                \\    .quad l_OBJC_METH_VAR_TYPE_.43
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.48
                \\    .quad l_OBJC_METH_VAR_TYPE_.43
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.49
                \\    .quad l_OBJC_METH_VAR_TYPE_.45
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.50
                \\    .quad l_OBJC_METH_VAR_TYPE_.51
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.52
                \\    .quad l_OBJC_METH_VAR_TYPE_.53
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.54
                \\    .quad l_OBJC_METH_VAR_TYPE_.43
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.55
                \\    .quad l_OBJC_METH_VAR_TYPE_.43
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.56
                \\    .quad l_OBJC_METH_VAR_TYPE_.43
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.57
                \\    .quad l_OBJC_METH_VAR_TYPE_.58
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.59
                \\    .quad l_OBJC_METH_VAR_TYPE_.60
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.61
                \\    .quad l_OBJC_METH_VAR_TYPE_.62
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.63
                \\    .quad l_OBJC_METH_VAR_TYPE_.62
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.64
                \\    .quad l_OBJC_METH_VAR_TYPE_.65
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.66
                \\    .quad l_OBJC_METH_VAR_TYPE_.65
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.67
                \\    .quad l_OBJC_METH_VAR_TYPE_.65
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.68
                \\    .quad l_OBJC_METH_VAR_TYPE_.65
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.69
                \\    .quad l_OBJC_METH_VAR_TYPE_.65
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.70
                \\    .quad l_OBJC_METH_VAR_TYPE_.71
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.72
                \\    .quad l_OBJC_METH_VAR_TYPE_.73
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.74
                \\    .quad l_OBJC_METH_VAR_TYPE_.71
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.75
                \\    .quad l_OBJC_METH_VAR_TYPE_.73
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.76
                \\    .quad l_OBJC_METH_VAR_TYPE_.77
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.78
                \\    .quad l_OBJC_METH_VAR_TYPE_.79
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.80
                \\    .quad l_OBJC_METH_VAR_TYPE_.77
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.81
                \\    .quad l_OBJC_METH_VAR_TYPE_.77
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.82
                \\    .quad l_OBJC_METH_VAR_TYPE_.77
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.83
                \\    .quad l_OBJC_METH_VAR_TYPE_.43
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.84
                \\    .quad l_OBJC_METH_VAR_TYPE_.85
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.86
                \\    .quad l_OBJC_METH_VAR_TYPE_.77
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.87
                \\    .quad l_OBJC_METH_VAR_TYPE_.43
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.88
                \\    .quad l_OBJC_METH_VAR_TYPE_.43
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.89
                \\    .quad l_OBJC_METH_VAR_TYPE_.43
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.90
                \\    .quad l_OBJC_METH_VAR_TYPE_.43
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.91
                \\    .quad l_OBJC_METH_VAR_TYPE_.92
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.93
                \\    .quad l_OBJC_METH_VAR_TYPE_.45
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.94
                \\    .quad l_OBJC_METH_VAR_TYPE_.95
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.96
                \\    .quad l_OBJC_METH_VAR_TYPE_.45
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.97
                \\    .quad l_OBJC_METH_VAR_TYPE_.45
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.98
                \\    .quad l_OBJC_METH_VAR_TYPE_.65
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.99
                \\    .quad l_OBJC_METH_VAR_TYPE_.65
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.100
                \\    .quad l_OBJC_METH_VAR_TYPE_.45
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.101
                \\    .quad l_OBJC_METH_VAR_TYPE_.45
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.102
                \\    .quad l_OBJC_METH_VAR_TYPE_.45
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.103
                \\    .quad l_OBJC_METH_VAR_TYPE_.104
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.105
                \\    .quad l_OBJC_METH_VAR_TYPE_.106
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.107
                \\    .quad l_OBJC_METH_VAR_TYPE_.65
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.108
                \\    .quad l_OBJC_METH_VAR_TYPE_.65
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.109
                \\    .quad l_OBJC_METH_VAR_TYPE_.95
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.110
                \\    .quad l_OBJC_METH_VAR_TYPE_.65
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.111
                \\    .quad l_OBJC_METH_VAR_TYPE_
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.112
                \\    .quad l_OBJC_METH_VAR_TYPE_.6
                \\    .quad 0
                \\    .quad l_OBJC_METH_VAR_NAME_.113
                \\    .quad l_OBJC_METH_VAR_TYPE_.43
                \\    .quad 0
                \\
                \\    .section __TEXT,__objc_methname,cstring_literals
                \\l_OBJC_PROP_NAME_ATTR_.114:
                \\    .asciz "window"
                \\
                \\l_OBJC_PROP_NAME_ATTR_.115:
                \\    .asciz "T@\"UIWindow\",?,&,N"
                \\
                \\    .section __DATA,__objc_const
                \\    .p2align 3, 0x0
                \\__OBJC_$_PROP_LIST_UIApplicationDelegate:
                \\    .long 16
                \\    .long 1
                \\    .quad l_OBJC_PROP_NAME_ATTR_.114
                \\    .quad l_OBJC_PROP_NAME_ATTR_.115
                \\
                \\    .section __TEXT,__objc_methtype,cstring_literals
                \\l_OBJC_METH_VAR_TYPE_.116:
                \\    .asciz "v24@0:8@\"UIApplication\"16"
                \\
                \\l_OBJC_METH_VAR_TYPE_.117:
                \\    .asciz "B32@0:8@\"UIApplication\"16@\"NSDictionary\"24"
                \\
                \\l_OBJC_METH_VAR_TYPE_.118:
                \\    .asciz "B32@0:8@\"UIApplication\"16@\"NSURL\"24"
                \\
                \\l_OBJC_METH_VAR_TYPE_.119:
                \\    .asciz "B48@0:8@\"UIApplication\"16@\"NSURL\"24@\"NSString\"32@40"
                \\
                \\l_OBJC_METH_VAR_TYPE_.120:
                \\    .asciz "B40@0:8@\"UIApplication\"16@\"NSURL\"24@\"NSDictionary\"32"
                \\
                \\l_OBJC_METH_VAR_TYPE_.121:
                \\    .asciz "v40@0:8@\"UIApplication\"16q24d32"
                \\
                \\l_OBJC_METH_VAR_TYPE_.122:
                \\    .asciz "v32@0:8@\"UIApplication\"16q24"
                \\
                \\l_OBJC_METH_VAR_TYPE_.123:
                \\    .asciz "v56@0:8@\"UIApplication\"16{CGRect={CGPoint=dd}{CGSize=dd}}24"
                \\
                \\l_OBJC_METH_VAR_TYPE_.124:
                \\    .asciz "v32@0:8@\"UIApplication\"16@\"UIUserNotificationSettings\"24"
                \\
                \\l_OBJC_METH_VAR_TYPE_.125:
                \\    .asciz "v32@0:8@\"UIApplication\"16@\"NSData\"24"
                \\
                \\l_OBJC_METH_VAR_TYPE_.126:
                \\    .asciz "v32@0:8@\"UIApplication\"16@\"NSError\"24"
                \\
                \\l_OBJC_METH_VAR_TYPE_.127:
                \\    .asciz "v32@0:8@\"UIApplication\"16@\"NSDictionary\"24"
                \\
                \\l_OBJC_METH_VAR_TYPE_.128:
                \\    .asciz "v32@0:8@\"UIApplication\"16@\"UILocalNotification\"24"
                \\
                \\l_OBJC_METH_VAR_TYPE_.129:
                \\    .asciz "v48@0:8@\"UIApplication\"16@\"NSString\"24@\"UILocalNotification\"32@?<v@?>40"
                \\
                \\l_OBJC_METH_VAR_TYPE_.130:
                \\    .asciz "v56@0:8@\"UIApplication\"16@\"NSString\"24@\"NSDictionary\"32@\"NSDictionary\"40@?<v@?>48"
                \\
                \\l_OBJC_METH_VAR_TYPE_.131:
                \\    .asciz "v48@0:8@\"UIApplication\"16@\"NSString\"24@\"NSDictionary\"32@?<v@?>40"
                \\
                \\l_OBJC_METH_VAR_TYPE_.132:
                \\    .asciz "v56@0:8@\"UIApplication\"16@\"NSString\"24@\"UILocalNotification\"32@\"NSDictionary\"40@?<v@?>48"
                \\
                \\l_OBJC_METH_VAR_TYPE_.133:
                \\    .asciz "v40@0:8@\"UIApplication\"16@\"NSDictionary\"24@?<v@?Q>32"
                \\
                \\l_OBJC_METH_VAR_TYPE_.134:
                \\    .asciz "v32@0:8@\"UIApplication\"16@?<v@?Q>24"
                \\
                \\l_OBJC_METH_VAR_TYPE_.135:
                \\    .asciz "v40@0:8@\"UIApplication\"16@\"UIApplicationShortcutItem\"24@?<v@?B>32"
                \\
                \\l_OBJC_METH_VAR_TYPE_.136:
                \\    .asciz "v40@0:8@\"UIApplication\"16@\"NSString\"24@?<v@?>32"
                \\
                \\l_OBJC_METH_VAR_TYPE_.137:
                \\    .asciz "v40@0:8@\"UIApplication\"16@\"NSDictionary\"24@?<v@?@\"NSDictionary\">32"
                \\
                \\l_OBJC_METH_VAR_TYPE_.138:
                \\    .asciz "@32@0:8@\"UIApplication\"16@\"INIntent\"24"
                \\
                \\l_OBJC_METH_VAR_TYPE_.139:
                \\    .asciz "v40@0:8@\"UIApplication\"16@\"INIntent\"24@?<v@?@\"INIntentResponse\">32"
                \\
                \\l_OBJC_METH_VAR_TYPE_.140:
                \\    .asciz "Q32@0:8@\"UIApplication\"16@\"UIWindow\"24"
                \\
                \\l_OBJC_METH_VAR_TYPE_.141:
                \\    .asciz "B32@0:8@\"UIApplication\"16@\"NSString\"24"
                \\
                \\l_OBJC_METH_VAR_TYPE_.142:
                \\    .asciz "@\"UIViewController\"40@0:8@\"UIApplication\"16@\"NSArray\"24@\"NSCoder\"32"
                \\
                \\l_OBJC_METH_VAR_TYPE_.143:
                \\    .asciz "B32@0:8@\"UIApplication\"16@\"NSCoder\"24"
                \\
                \\l_OBJC_METH_VAR_TYPE_.144:
                \\    .asciz "v32@0:8@\"UIApplication\"16@\"NSCoder\"24"
                \\
                \\l_OBJC_METH_VAR_TYPE_.145:
                \\    .asciz "B40@0:8@\"UIApplication\"16@\"NSUserActivity\"24@?<v@?@\"NSArray\">32"
                \\
                \\l_OBJC_METH_VAR_TYPE_.146:
                \\    .asciz "v40@0:8@\"UIApplication\"16@\"NSString\"24@\"NSError\"32"
                \\
                \\l_OBJC_METH_VAR_TYPE_.147:
                \\    .asciz "v32@0:8@\"UIApplication\"16@\"NSUserActivity\"24"
                \\
                \\l_OBJC_METH_VAR_TYPE_.148:
                \\    .asciz "v32@0:8@\"UIApplication\"16@\"CKShareMetadata\"24"
                \\
                \\l_OBJC_METH_VAR_TYPE_.149:
                \\    .asciz "@\"UISceneConfiguration\"40@0:8@\"UIApplication\"16@\"UISceneSession\"24@\"UISceneConnectionOptions\"32"
                \\
                \\l_OBJC_METH_VAR_TYPE_.150:
                \\    .asciz "v32@0:8@\"UIApplication\"16@\"NSSet\"24"
                \\
                \\l_OBJC_METH_VAR_TYPE_.151:
                \\    .asciz "B24@0:8@\"UIApplication\"16"
                \\
                \\l_OBJC_METH_VAR_TYPE_.152:
                \\    .asciz "@\"UIWindow\"16@0:8"
                \\
                \\l_OBJC_METH_VAR_TYPE_.153:
                \\    .asciz "v24@0:8@\"UIWindow\"16"
                \\
                \\    .section __DATA,__objc_const
                \\    .p2align 3, 0x0
                \\__OBJC_$_PROTOCOL_METHOD_TYPES_UIApplicationDelegate:
                \\    .quad l_OBJC_METH_VAR_TYPE_.116
                \\    .quad l_OBJC_METH_VAR_TYPE_.117
                \\    .quad l_OBJC_METH_VAR_TYPE_.117
                \\    .quad l_OBJC_METH_VAR_TYPE_.116
                \\    .quad l_OBJC_METH_VAR_TYPE_.116
                \\    .quad l_OBJC_METH_VAR_TYPE_.118
                \\    .quad l_OBJC_METH_VAR_TYPE_.119
                \\    .quad l_OBJC_METH_VAR_TYPE_.120
                \\    .quad l_OBJC_METH_VAR_TYPE_.116
                \\    .quad l_OBJC_METH_VAR_TYPE_.116
                \\    .quad l_OBJC_METH_VAR_TYPE_.116
                \\    .quad l_OBJC_METH_VAR_TYPE_.121
                \\    .quad l_OBJC_METH_VAR_TYPE_.122
                \\    .quad l_OBJC_METH_VAR_TYPE_.123
                \\    .quad l_OBJC_METH_VAR_TYPE_.123
                \\    .quad l_OBJC_METH_VAR_TYPE_.124
                \\    .quad l_OBJC_METH_VAR_TYPE_.125
                \\    .quad l_OBJC_METH_VAR_TYPE_.126
                \\    .quad l_OBJC_METH_VAR_TYPE_.127
                \\    .quad l_OBJC_METH_VAR_TYPE_.128
                \\    .quad l_OBJC_METH_VAR_TYPE_.129
                \\    .quad l_OBJC_METH_VAR_TYPE_.130
                \\    .quad l_OBJC_METH_VAR_TYPE_.131
                \\    .quad l_OBJC_METH_VAR_TYPE_.132
                \\    .quad l_OBJC_METH_VAR_TYPE_.133
                \\    .quad l_OBJC_METH_VAR_TYPE_.134
                \\    .quad l_OBJC_METH_VAR_TYPE_.135
                \\    .quad l_OBJC_METH_VAR_TYPE_.136
                \\    .quad l_OBJC_METH_VAR_TYPE_.137
                \\    .quad l_OBJC_METH_VAR_TYPE_.116
                \\    .quad l_OBJC_METH_VAR_TYPE_.138
                \\    .quad l_OBJC_METH_VAR_TYPE_.139
                \\    .quad l_OBJC_METH_VAR_TYPE_.116
                \\    .quad l_OBJC_METH_VAR_TYPE_.116
                \\    .quad l_OBJC_METH_VAR_TYPE_.116
                \\    .quad l_OBJC_METH_VAR_TYPE_.116
                \\    .quad l_OBJC_METH_VAR_TYPE_.140
                \\    .quad l_OBJC_METH_VAR_TYPE_.141
                \\    .quad l_OBJC_METH_VAR_TYPE_.142
                \\    .quad l_OBJC_METH_VAR_TYPE_.143
                \\    .quad l_OBJC_METH_VAR_TYPE_.143
                \\    .quad l_OBJC_METH_VAR_TYPE_.144
                \\    .quad l_OBJC_METH_VAR_TYPE_.144
                \\    .quad l_OBJC_METH_VAR_TYPE_.143
                \\    .quad l_OBJC_METH_VAR_TYPE_.143
                \\    .quad l_OBJC_METH_VAR_TYPE_.141
                \\    .quad l_OBJC_METH_VAR_TYPE_.145
                \\    .quad l_OBJC_METH_VAR_TYPE_.146
                \\    .quad l_OBJC_METH_VAR_TYPE_.147
                \\    .quad l_OBJC_METH_VAR_TYPE_.148
                \\    .quad l_OBJC_METH_VAR_TYPE_.149
                \\    .quad l_OBJC_METH_VAR_TYPE_.150
                \\    .quad l_OBJC_METH_VAR_TYPE_.151
                \\    .quad l_OBJC_METH_VAR_TYPE_.152
                \\    .quad l_OBJC_METH_VAR_TYPE_.153
                \\
                \\    .private_extern __OBJC_PROTOCOL_$_UIApplicationDelegate
                \\    .section __DATA,__data
                \\    .globl __OBJC_PROTOCOL_$_UIApplicationDelegate
                \\    .weak_definition __OBJC_PROTOCOL_$_UIApplicationDelegate
                \\    .p2align 3, 0x0
                \\__OBJC_PROTOCOL_$_UIApplicationDelegate:
                \\    .quad 0
                \\    .quad l_OBJC_CLASS_NAME_.1
                \\    .quad __OBJC_$_PROTOCOL_REFS_UIApplicationDelegate
                \\    .quad 0
                \\    .quad 0
                \\    .quad __OBJC_$_PROTOCOL_INSTANCE_METHODS_OPT_UIApplicationDelegate
                \\    .quad 0
                \\    .quad __OBJC_$_PROP_LIST_UIApplicationDelegate
                \\    .long 96
                \\    .long 0
                \\    .quad __OBJC_$_PROTOCOL_METHOD_TYPES_UIApplicationDelegate
                \\    .quad 0
                \\    .quad 0
                \\
                \\    .private_extern __OBJC_LABEL_PROTOCOL_$_UIApplicationDelegate
                \\    .section __DATA,__objc_protolist,coalesced,no_dead_strip
                \\    .globl __OBJC_LABEL_PROTOCOL_$_UIApplicationDelegate
                \\    .weak_definition __OBJC_LABEL_PROTOCOL_$_UIApplicationDelegate
                \\    .p2align 3, 0x0
                \\__OBJC_LABEL_PROTOCOL_$_UIApplicationDelegate:
                \\    .quad __OBJC_PROTOCOL_$_UIApplicationDelegate
                \\
                \\    .section __DATA,__objc_const
                \\    .p2align 3, 0x0
                \\__OBJC_CLASS_PROTOCOLS_$_MachApp:
                \\    .quad 1
                \\    .quad __OBJC_PROTOCOL_$_UIApplicationDelegate
                \\    .quad 0
                \\
                \\    .p2align 3, 0x0
                \\__OBJC_METACLASS_RO_$_MachApp:
                \\    .long 129
                \\    .long 40
                \\    .long 40
                \\    .space 4
                \\    .quad 0
                \\    .quad l_OBJC_CLASS_NAME_
                \\    .quad 0
                \\    .quad __OBJC_CLASS_PROTOCOLS_$_MachApp
                \\    .quad 0
                \\    .quad 0
                \\    .quad 0
                \\
                \\    .section __DATA,__objc_data
                \\    .globl _OBJC_METACLASS_$_MachApp
                \\    .p2align 3, 0x0
                \\_OBJC_METACLASS_$_MachApp:
                \\    .quad _OBJC_METACLASS_$_NSObject
                \\    .quad _OBJC_METACLASS_$_NSObject
                \\    .quad __objc_empty_cache
                \\    .quad 0
                \\    .quad __OBJC_METACLASS_RO_$_MachApp
                \\
                \\    .section __DATA,__objc_const
                \\    .p2align 3, 0x0
                \\__OBJC_$_INSTANCE_METHODS_MachApp:
                \\    .long 24
                \\    .long 1
                \\    .quad l_OBJC_METH_VAR_NAME_.46
                \\    .quad l_OBJC_METH_VAR_TYPE_.45
                \\    .quad "-[MachApp application:didFinishLaunchingWithOptions:]"
                \\
                \\    .p2align 3, 0x0
                \\__OBJC_$_PROP_LIST_MachApp:
                \\    .long 16
                \\    .long 5
                \\    .quad l_OBJC_PROP_NAME_ATTR_.114
                \\    .quad l_OBJC_PROP_NAME_ATTR_.115
                \\    .quad l_OBJC_PROP_NAME_ATTR_
                \\    .quad l_OBJC_PROP_NAME_ATTR_.33
                \\    .quad l_OBJC_PROP_NAME_ATTR_.34
                \\    .quad l_OBJC_PROP_NAME_ATTR_.35
                \\    .quad l_OBJC_PROP_NAME_ATTR_.36
                \\    .quad l_OBJC_PROP_NAME_ATTR_.37
                \\    .quad l_OBJC_PROP_NAME_ATTR_.38
                \\    .quad l_OBJC_PROP_NAME_ATTR_.39
                \\
                \\    .p2align 3, 0x0
                \\__OBJC_CLASS_RO_$_MachApp:
                \\    .long 128
                \\    .long 8
                \\    .long 8
                \\    .space 4
                \\    .quad 0
                \\    .quad l_OBJC_CLASS_NAME_
                \\    .quad __OBJC_$_INSTANCE_METHODS_MachApp
                \\    .quad __OBJC_CLASS_PROTOCOLS_$_MachApp
                \\    .quad 0
                \\    .quad 0
                \\    .quad __OBJC_$_PROP_LIST_MachApp
                \\
                \\    .section __DATA,__objc_data
                \\    .globl _OBJC_CLASS_$_MachApp
                \\    .p2align 3, 0x0
                \\_OBJC_CLASS_$_MachApp:
                \\    .quad _OBJC_METACLASS_$_MachApp
                \\    .quad _OBJC_CLASS_$_NSObject
                \\    .quad __objc_empty_cache
                \\    .quad 0
                \\    .quad __OBJC_CLASS_RO_$_MachApp
                \\
                \\    .section __DATA,__objc_classlist,regular,no_dead_strip
                \\    .p2align 3, 0x0
                \\l_OBJC_LABEL_CLASS_$:
                \\    .quad _OBJC_CLASS_$_MachApp
                \\
                \\    .no_dead_strip __OBJC_LABEL_PROTOCOL_$_NSObject
                \\    .no_dead_strip __OBJC_LABEL_PROTOCOL_$_UIApplicationDelegate
                \\    .no_dead_strip __OBJC_PROTOCOL_$_NSObject
                \\    .no_dead_strip __OBJC_PROTOCOL_$_UIApplicationDelegate
                \\    .section __DATA,__objc_imageinfo,regular,no_dead_strip
                \\L_OBJC_IMAGE_INFO:
                \\    .long 0
                \\    .long 64
                \\
                \\.subsections_via_symbols
            );
        }
    }
}
