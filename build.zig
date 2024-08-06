const std = @import("std");

// See also https://github.com/Gordon-F/cargo-xcodebuild/tree/main and https://github.com/kubkon/zig-ios-example/blob/main/build.zig

// zig build -Dtarget=aarch64-ios-simulator
// If cross compiling: zig build --sysroot <path_to_sdk> -Dtarget=aarch64-ios-simulator
// Example: zig build -Dtarget=aarch64-ios-simulator --sysroot /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator.sdk
// TODO: zig has a bug when building for the iOS simulator. When invoking `ld`, it passes `-platform_version ios` instead of `-platform_version ios-simulator`. Test with zig HEAD and see if it still happens, and if so, fix it. To work around it, pass `--verbose-link` when building and copy the `ld` command and execute it with a corrected `-platform_version` arg. Also note the bad search paths that `ld` warns about.
// TODO: I think zig has a caching issue when changing targets from macOS to iOS. For example, building for iOS executes a linker command for macOS, and the first attempt at linking for iOS fails.

// Install and run on simulator:
// xcrun simctl install booted zig-out/bin/MachDemo.app
// xcrun simctl launch --console booted org.machengine.objc-demo
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

    // const ams_file = b.addInstallFile(demo.getEmittedAsm(), "demo.s");
    // b.getInstallStep().dependOn(&ams_file.step);
}

// Currently we only target:
//
//   - macOS 12+
//   - iOS 15+
//   - tvOS 15+
//   - visionOS 1+
//   - watchOS 8+
//
// Except watchOS isn't actually supported because it doesn't support UIKit or AppKit. Support could
// be added if someone is motivated enough. And I don't plan on testing tvOS or visionOS for now.
//
// We probably won't need all of the following commands. Realistically we only need 4: iOS
// arm64/x86_64 and macOS arm64/x86_64. The generated assembly code is (generally) the same across
// all the platforms. The only reason iOS and macOS require separate assembly blobs is because they
// use different APIs (UIKit vs AppKit).
//
// To generate updated assembly, run the `generate_asm.sh` script.
//
// Below are all of the following commands that could be used for generating the assembly. You don't
// need all these commands in general. I just got tired of trying to remember them.
//
// iOS arm64 device: cc -c file.m -o arm64-apple-ios15.s -target arm64-apple-ios15 -S -Os -fomit-frame-pointer -fobjc-arc -fno-objc-exceptions -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk
// iOS arm64 simulator: cc -c file.m -o arm64-apple-ios15-sim.s -target arm64-apple-ios15-simulator -S -Os -fomit-frame-pointer -fobjc-arc -fno-objc-exceptions -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator.sdk
// iOS x86_64 simulator: cc -c file.m -o x86_64-apple-ios15-sim.s -target x86_64-apple-ios15-simulator -S -Os -fomit-frame-pointer -fobjc-arc -fno-objc-exceptions -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator.sdk
//
// macOS arm64: cc -c file.m -o arm64-apple-macos12.s -target arm64-apple-macos12 -S -Os -fomit-frame-pointer -fobjc-arc -fno-objc-exceptions -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk
// macOS x86_64: cc -c file.m -o x86_64-apple-macos12.s -target x86_64-apple-macos12 -S -Os -fomit-frame-pointer -fobjc-arc -fno-objc-exceptions -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk
//
// Mac Catalyst arm64: cc -c file.m -o arm64-apple-ios15-macabi.s -target arm64-apple-ios15-macabi -S -Os -fomit-frame-pointer -fobjc-arc -fno-objc-exceptions -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk -iframework /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/System/iOSSupport/System/Library/Frameworks
// Mac Catalyst x86_64: cc -c file.m -o x86_64-apple-ios15-macabi.s -target x86_64-apple-ios15-macabi -S -Os -fomit-frame-pointer -fobjc-arc -fno-objc-exceptions -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk -iframework /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/System/iOSSupport/System/Library/Frameworks
//
// visionOS arm64 device: cc -c file.m -o arm64-apple-xros12.s -target arm64-apple-xros12 -S -Os -fomit-frame-pointer -fobjc-arc -fno-objc-exceptions -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/XROS.platform/Developer/SDKs/XROS.sdk
// visionOS arm64 simulator: cc -c file.m -o arm64-apple-xros12-sim.s -target arm64-apple-xros12-simulator -S -Os -fomit-frame-pointer -fobjc-arc -fno-objc-exceptions -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/XRSimulator.platform/Developer/SDKs/XRSimulator.sdk
//
// watchOS arm64 device: cc -c file.m -o arm64-apple-watchos8.s -target arm64-apple-watchos8 -S -Os -fomit-frame-pointer -fobjc-arc -fno-objc-exceptions -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/WatchOS.platform/Developer/SDKs/WatchOS.sdk
// watchOS arm64 simulator: cc -c file.m -o arm64-apple-watchos8-sim.s -target arm64-apple-watchos8-simulator -S -Os -fomit-frame-pointer -fobjc-arc -fno-objc-exceptions -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/WatchSimulator.platform/Developer/SDKs/WatchSimulator.sdk
// watchOS x86_64 simulator: cc -c file.m -o x86_64-apple-watchos8-sim.s -target x86_64-apple-watchos8-simulator -S -Os -fomit-frame-pointer -fobjc-arc -fno-objc-exceptions -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/WatchSimulator.platform/Developer/SDKs/WatchSimulator.sdk
//
// tvOS arm64 device: cc -c file.m -o arm64-apple-tvos15.s -target arm64-apple-tvos15 -S -Os -fomit-frame-pointer -fobjc-arc -fno-objc-exceptions -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/AppleTVOS.platform/Developer/SDKs/AppleTVOS.sdk
// tvOS arm64 simulator: cc -c file.m -o arm64-apple-tvos15-sim.s -target arm64-apple-tvos15-simulator -S -Os -fomit-frame-pointer -fobjc-arc -fno-objc-exceptions -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/AppleTVSimulator.platform/Developer/SDKs/AppleTVSimulator.sdk
// tvOS x86_64 simulator: cc -c file.m -o x86_64-apple-tvos15-sim.s -target x86_64-apple-tvos15-simulator -S -Os -fomit-frame-pointer -fobjc-arc -fno-objc-exceptions -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/AppleTVSimulator.platform/Developer/SDKs/AppleTVSimulator.sdk
//