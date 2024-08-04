const std = @import("std");
const builtin = @import("builtin");
const objc = @import("objc");
const NSObject = @import("NSObject.zig").NSObject;

fn isAsciiString(comptime str: []const u8) bool {
    for (str) |c| {
        // TODO: clang also uses UTF-16 for ASCII strings that contain the NUL character. Is that actually a requirement we must follow?
        if (!std.ascii.isASCII(c)) return false;
    }
    return true;
}

// TODO: use CFString APIs for some operations
pub const NSString = opaque {
    pub const ZigInfo = objc.ExternClass("NSString");

    pub fn super(self: *NSString) *NSObject {
        return @ptrCast(self);
    }

    /// If you might have multiple strings with the same contents, use `literalWithUniqueId()` and provide a unique ID for each string.
    pub inline fn literal(comptime utf8: []const u8) *NSString {
        // Another option is to take a `SourceLocation` parameter and use that as part of the hash. But let's keep this simple for now.
        const hash = comptime std.hash.Wyhash.hash(0x57325bbf446493ac, utf8);
        const unique_id = comptime std.fmt.comptimePrint("{x:0>16}", .{hash});
        return literalWithUniqueId(utf8, unique_id);
    }

    pub inline fn literalWithUniqueId(comptime utf8: []const u8, comptime unique_id: []const u8) *NSString {
        if (comptime isAsciiString(utf8)) {
            return asciiLiteralWithUniqueId(utf8, unique_id);
        } else {
            return utf16LiteralWithUniqueId(std.unicode.utf8ToUtf16LeStringLiteral(utf8), unique_id);
        }
    }

    fn asciiLiteralWithUniqueId(comptime ascii: []const u8, comptime unique_id: []const u8) *NSString {
        const local_prefix = if (comptime builtin.cpu.arch == .x86_64) "L" else "l";

        _ = struct {
            comptime {
                var str_data: []const u8 = "";
                for (ascii) |c| {
                    str_data = str_data ++ std.fmt.comptimePrint("    .byte {}\n", .{c});
                }
                str_data = str_data ++ "    .byte 0";

                // zig fmt: off
                asm (
                    "    .section __TEXT,__cstring,cstring_literals\n" ++
                    local_prefix ++ "_.str." ++ unique_id ++ ":\n" ++
                    str_data ++ "\n\n" ++
                    "    .section __DATA,__cfstring\n" ++
                    "    .p2align 3, 0x0\n" ++
                    local_prefix ++ "__unnamed_cfstring_." ++ unique_id ++ ":\n" ++
                    "    .quad ___CFConstantStringClassReference\n" ++
                    "    .long 1992\n" ++
                    "    .space 4\n" ++
                    "    .quad " ++ local_prefix ++ "_.str." ++ unique_id ++ "\n" ++
                    std.fmt.comptimePrint("    .quad {}\n", .{ascii.len})
                );
                // zig fmt: on
            }
        };

        return @extern(*NSString, .{ .name = "\x01" ++ local_prefix ++ "__unnamed_cfstring_." ++ unique_id });
    }

    fn utf16LiteralWithUniqueId(comptime utf16: []const u16, comptime unique_id: []const u8) *NSString {
        const local_prefix = if (comptime builtin.cpu.arch == .x86_64) "L" else "l";

        _ = struct {
            comptime {
                var str_data: []const u8 = "";
                for (utf16) |c| {
                    str_data = str_data ++ std.fmt.comptimePrint("    .short {}\n", .{c});
                }
                str_data = str_data ++ "    .short 0";

                // zig fmt: off
                asm (
                    "    .section __TEXT,__ustring\n" ++
                    "    .p2align 1, 0x0\n" ++
                    "l_.str." ++ unique_id ++ ":\n" ++
                    str_data ++ "\n\n" ++
                    "    .section __DATA,__cfstring\n" ++
                    "    .p2align 3, 0x0\n" ++
                    local_prefix ++ "__unnamed_cfstring_." ++ unique_id ++ ":\n" ++
                    "    .quad ___CFConstantStringClassReference\n" ++
                    "    .long 2000\n" ++
                    "    .space 4\n" ++
                    "    .quad l_.str." ++ unique_id ++ "\n" ++
                    std.fmt.comptimePrint("    .quad {}\n", .{utf16.len})
                );
                // zig fmt: on
            }
        };

        return @extern(*NSString, .{ .name = "\x01" ++ local_prefix ++ "__unnamed_cfstring_." ++ unique_id });
    }

    /// `+[NSString alloc]`
    pub fn alloc() *NSString {
        return @ptrCast(objc.objc_alloc(ZigInfo.objcClass()));
    }

    /// `[[NSString alloc] init]`
    pub fn allocInit() *NSString {
        return @ptrCast(objc.objc_alloc_init(ZigInfo.objcClass()));
    }

    /// `-[NSString init]`
    pub fn init(self: *NSString) *NSString {
        return objc.msgSend(self, "init", *NSString, .{});
    }

    /// `+[NSString stringWithUTF8String:]`
    pub fn stringWithUtf8String(utf8_string: [*:0]const u8) *NSString {
        const c_str: [*:0]const c_char = @ptrCast(utf8_string);
        return objc.msgSend(ZigInfo.objcClass(), "stringWithUTF8String:", *NSString, .{c_str});
    }

    /// `-[NSString UTF8String]`
    pub fn utf8String(self: *NSString) [*:0]const u8 {
        return @ptrCast(objc.msgSend(self, "UTF8String", [*:0]const c_char, .{}));
    }

    /// `-[NSString isEqualToString:]`
    pub fn isEqualToString(self: *NSString, other: *NSString) bool {
        return objc.msgSend(self, "isEqualToString:", objc.BOOL, .{other}) != 0;
    }
};
