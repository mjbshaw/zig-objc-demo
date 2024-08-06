const std = @import("std");
const builtin = @import("builtin");

// libobjc.dylib
const AutoreleasePoolPage = opaque {};
pub extern "objc" fn objc_autoreleasePoolPush() *AutoreleasePoolPage;
pub extern "objc" fn objc_autoreleasePoolPop(*AutoreleasePoolPage) void;

pub extern "objc" fn objc_autorelease(*id) *id; // Same as [object autorelease].
pub extern "objc" fn objc_release(*id) void; // Same as [object release].
pub extern "objc" fn objc_retain(*id) *id; // Same as [object retain].

pub extern "objc" fn objc_alloc(class: *Class) ?*id; // Same as [Class alloc].
pub extern "objc" fn objc_alloc_init(class: *Class) ?*id; // Same as [[Class alloc] init].
pub extern "objc" fn objc_opt_new(class: *Class) ?*id; // Same as [Class new].

// libobjc.dylib
pub extern "objc" fn objc_getClass(name: [*:0]const c_char) *Class;
pub extern "objc" fn objc_getProtocol(name: [*:0]const c_char) *Protocol;
pub extern "objc" fn class_addProtocol(class: ?*Class, protocol: *Protocol) BOOL;
pub extern "objc" fn objc_allocateClassPair(superclass: ?*Class, name: [*:0]const c_char, extra_bytes: usize) ?*Class;
pub extern "objc" fn class_addMethod(class: ?*Class, name: SEL, imp: *const anyopaque, types: ?[*:0]const c_char) BOOL;

pub const SEL = [*:0]const c_char;
pub const BOOL = u8;

pub const id = opaque {};
// const Class = packed struct { base: id };
// const Protocol = packed struct { base: id };
pub const Class = id;
pub const Protocol = id;

pub const AvailabilityPlatforms = struct {
    macos: std.SemanticVersion = .{ 0, 0, 0 },
    ios: std.SemanticVersion = .{ 0, 0, 0 },
    tvos: std.SemanticVersion = .{ 0, 0, 0 },
    watchos: std.SemanticVersion = .{ 0, 0, 0 },
    driverkit: std.SemanticVersion = .{ 0, 0, 0 },
    visionos: std.SemanticVersion = .{ 0, 0, 0 },
};

// This requires CoreFoundation to be linked on macOS 10.14 and below, iOS/tvOS 12 and below, or watchOS 5 and below. I'm not going to worry about that, though.
extern fn __isPlatformVersionAtLeast(platform: u32, major: u32, minor: u32, patch: u32) i32;

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

    // Fun fact, `__builtin_available` on Android uses `int32_t __isOSVersionAtLeast(int32_t Major, int32_t Minor, int32_t Subminor)`.
    return __isPlatformVersionAtLeast(query[0], query[1].major, query[1].minor, query[1].patch) != 0;
}

fn fieldTypes(struct_type: type) []type {
    const fields = std.meta.fields(struct_type);
    var field_types: []type = .{};
    for (fields) |field| {
        field_types = field_types ++ .{field.type};
    }
    return field_types;
}

pub inline fn msgSend(receiver: anytype, comptime selector: []const u8, return_type: type, args: anytype) return_type {
    const n_colons = comptime std.mem.count(u8, selector, ":");
    if (comptime n_colons != args.len) {
        const plural = comptime if (n_colons == 1) "" else "s";
        const error_msg = comptime std.fmt.comptimePrint("Selector `{s}` has {} argument{s}, but {} were given", .{ selector, n_colons, plural, args.len });
        @compileError(error_msg);
    }

    const fn_type = comptime init: {
        var params_types: []const std.builtin.Type.Fn.Param = &.{
            .{
                .is_generic = false,
                .is_noalias = false,
                .type = @TypeOf(receiver),
            },
            .{
                .is_generic = false,
                .is_noalias = false,
                .type = [*:0]c_char,
            },
        };
        for (@typeInfo(@TypeOf(args)).Struct.fields) |field| {
            params_types = params_types ++
                .{.{
                .is_generic = false,
                .is_noalias = false,
                .type = field.type,
            }};
        }
        break :init std.builtin.Type{
            .Fn = .{
                .calling_convention = .C,
                .is_generic = false,
                .is_var_args = false,
                .return_type = return_type,
                .params = params_types,
            },
        };
    };

    // TODO: double check that "objc_msgSend(_stret)$selector" actually works for x86_64 (especially stret). If not, use real selectors.
    const needs_stret = comptime builtin.target.cpu.arch == .x86_64 and @sizeOf(return_type) > 16;
    const msg_send_fn_name = comptime if (needs_stret) "objc_msgSend_stret" else "objc_msgSend";
    const msg_send_fn = @extern(*const @Type(fn_type), .{ .name = msg_send_fn_name ++ "$" ++ selector });
    return @call(.auto, msg_send_fn, .{receiver, undefined} ++ args);
}

pub fn ExternClass(name: anytype) type {
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
