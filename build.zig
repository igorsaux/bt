// MIT License
//
// Copyright (c) 2025 Igor Spichkin
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const bt = b.addModule("bt", .{
        .root_source_file = b.path("src/bt.zig"),
        .target = target,
    });

    const bt_client = b.addExecutable(.{
        .name = "btc",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/btc.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "bt", .module = bt },
            },
        }),
    });

    b.installArtifact(bt_client);

    const bt_server = b.addExecutable(.{
        .name = "bts",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/bts.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "bt", .module = bt },
            },
        }),
    });

    b.installArtifact(bt_server);

    // "client" step
    {
        const run = b.addRunArtifact(bt_client);
        run.step.dependOn(b.getInstallStep());

        if (b.args) |args| {
            run.addArgs(args);
        }

        const step = b.step("client", "Run the client");
        step.dependOn(&run.step);
    }

    // "server" step
    {
        const run = b.addRunArtifact(bt_server);
        run.step.dependOn(b.getInstallStep());

        if (b.args) |args| {
            run.addArgs(args);
        }

        const step = b.step("server", "Run the server");
        step.dependOn(&run.step);
    }

    // "test" step
    {
        const bt_tests = b.addTest(.{
            .root_module = bt,
        });
        const run_bt_tests = b.addRunArtifact(bt_tests);

        const cli_tests = b.addTest(.{
            .root_module = b.addModule("cli", .{
                .root_source_file = b.path("src/cli.zig"),
                .target = target,
                .optimize = optimize,
                .imports = &.{
                    .{ .name = "bt", .module = bt },
                },
            }),
        });
        const run_cli_tests = b.addRunArtifact(cli_tests);

        const step = b.step("test", "Run tests");
        step.dependOn(&run_bt_tests.step);
        step.dependOn(&run_cli_tests.step);
    }
}
