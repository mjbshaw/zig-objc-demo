const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    const objc = b.addModule("objc", .{
        .root_source_file = b.path("objc.zig"),
        .optimize = optimize,
        .target = target,
    });
    objc.linkSystemLibrary("objc", .{ .needed = true });

    const dispatch = b.addModule("dispatch", .{
        .root_source_file = b.path("dispatch/dispatch.zig"),
        .optimize = optimize,
        .target = target,
    });
    objc.linkSystemLibrary("System", .{ .needed = true });

    const foundation = b.addModule("Foundation", .{
        .root_source_file = b.path("Foundation/Foundation.zig"),
        .optimize = optimize,
        .target = target,
        .imports = &.{
            .{ .name = "objc", .module = objc },
        },
    });
    foundation.linkFramework("CoreFoundation", .{ .needed = true });
    foundation.linkFramework("Foundation", .{ .needed = true });

    var kit: *std.Build.Module = undefined;
    var kit_name: []const u8 = undefined;
    if (target.result.os.tag == .macos) {
        const app_kit = b.addModule("AppKit", .{
            .root_source_file = b.path("AppKit/AppKit.zig"),
            .optimize = optimize,
            .target = target,
            .imports = &.{
                .{ .name = "objc", .module = objc },
                .{ .name = "Foundation", .module = foundation },
            },
        });
        app_kit.linkFramework("AppKit", .{ .needed = true });
        kit = app_kit;
        kit_name = "AppKit";
    } else {
        const ui_kit = b.addModule("UIKit", .{
            .root_source_file = b.path("UIKit/UIKit.zig"),
            .optimize = optimize,
            .target = target,
            .imports = &.{
                .{ .name = "objc", .module = objc },
                .{ .name = "Foundation", .module = foundation },
            },
        });
        ui_kit.linkFramework("UIKit", .{ .needed = true });
        kit = ui_kit;
        kit_name = "UIKit";
    }

    const demo = b.addExecutable(.{
        .name = "demo",
        .root_source_file = b.path("main.zig"),
        .target = target,
        .optimize = optimize,
        .strip = true,
    });
    if (target.result.os.tag == .macos) {
        if (target.result.cpu.arch == .x86_64) {
            demo.addAssemblyFile(b.path("x86_64-apple-macos12.s"));
        } else {
            demo.addAssemblyFile(b.path("arm64-apple-macos12.s"));
        }
    } else {
        if (target.result.cpu.arch == .x86_64) {
            demo.addAssemblyFile(b.path("x86_64-apple-ios15-sim.s"));
        } else {
            demo.addAssemblyFile(b.path("arm64-apple-ios15.s"));
        }
    }
    demo.root_module.addImport("Foundation", foundation);
    demo.root_module.addImport("objc", objc);
    demo.root_module.addImport("dispatch", dispatch);
    demo.root_module.addImport(kit_name, kit);
    b.installArtifact(demo);

    const ams_file = b.addInstallFile(demo.getEmittedAsm(), "demo.s");
    b.getInstallStep().dependOn(&ams_file.step);
}
