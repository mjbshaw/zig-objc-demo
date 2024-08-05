const std = @import("std");

// See also https://github.com/Gordon-F/cargo-xcodebuild/tree/main and https://github.com/kubkon/zig-ios-example/blob/main/build.zig

// zig build -Dtarget=aarch64-ios-simulator
// If cross compiling: zig build --sysroot <path_to_sdk> -Dtarget=aarch64-ios-simulator
// Example: zig build -Dtarget=aarch64-ios-simulator --sysroot /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator.sdk

// Install and run on simulator:
// xcrun simctl install booted zig-out/bin/MachDemo.app
// xcrun simctl launch booted MachDemo
pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    // TODO: maybe use https://github.com/hexops/xcode-frameworks for the sysroot? That way cross compiling would be easy.
    if (b.sysroot == null) {
        b.sysroot = std.zig.system.darwin.getSdk(b.allocator, target.result);
    }

    const objc = b.addModule("objc", .{
        .root_source_file = b.path("objc.zig"),
        .optimize = optimize,
        .target = target,
    });
    objc.linkSystemLibrary("objc", .{ .needed = true });

    const dispatch = b.addModule("dispatch", .{
        .root_source_file = b.path("dispatch.zig"),
        .optimize = optimize,
        .target = target,
    });
    objc.linkSystemLibrary("System", .{ .needed = true });

    const core_foundation = b.addModule("CoreFoundation", .{
        .root_source_file = b.path("CoreFoundation.zig"),
        .optimize = optimize,
        .target = target,
        .imports = &.{
            .{ .name = "objc", .module = objc },
        },
    });
    core_foundation.linkFramework("CoreFoundation", .{ .needed = true });

    const foundation = b.addModule("Foundation", .{
        .root_source_file = b.path("Foundation.zig"),
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
            .root_source_file = b.path("AppKit.zig"),
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
            .root_source_file = b.path("UIKit.zig"),
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
    demo.root_module.addImport("CoreFoundation", core_foundation);
    demo.root_module.addImport("Foundation", foundation);
    demo.root_module.addImport("objc", objc);
    demo.root_module.addImport("dispatch", dispatch);
    demo.root_module.addImport(kit_name, kit);
    if (b.sysroot) |sysroot| {
        demo.addSystemFrameworkPath(.{ .cwd_relative = b.pathJoin(&.{ sysroot, "/System/Library/Frameworks" }) });
        demo.addLibraryPath(.{ .cwd_relative = b.pathJoin(&.{ sysroot, "/usr/lib" }) });
    }
    const install_bin = b.addInstallArtifact(demo, .{});
    b.getInstallStep().dependOn(&install_bin.step);

    if (target.result.os.tag != .macos) {
        const install_app_bin = b.addInstallFile(install_bin.emitted_bin.?, "bin/MachDemo.app/MachDemo");
        install_app_bin.step.dependOn(&install_bin.step);
        const install_app_plist = b.addInstallFile(b.path("plist/ios/Info.plist"), "bin/MachDemo.app/Info.plist");

        b.getInstallStep().dependOn(&install_app_bin.step);
        b.getInstallStep().dependOn(&install_app_plist.step);
    }

    const ams_file = b.addInstallFile(demo.getEmittedAsm(), "demo.s");
    b.getInstallStep().dependOn(&ams_file.step);
}
