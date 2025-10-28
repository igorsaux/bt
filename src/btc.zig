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
const bt = @import("bt");
const cli = @import("cli.zig");

const Args = cli.ClientArgs;

fn printUsage() void {
    std.debug.print("Usage: btc <HOST>:<PORT> <QUERY>\n", .{});
}

pub fn main() !void {
    var alloc = std.heap.DebugAllocator(.{}).init;
    defer _ = alloc.deinit();

    const args = try std.process.argsAlloc(alloc.allocator());
    defer std.process.argsFree(alloc.allocator(), args);

    var parse_err: Args.Error = .{};
    const app_args = Args.parse(args, &parse_err) catch |err| {
        std.debug.print("{s}", .{@errorName(err)});

        if (parse_err.target) |target| {
            std.debug.print(": \"{s}\"", .{target});
        }

        std.debug.print("\n", .{});
        printUsage();
        std.process.exit(1);
    };

    var stdout_buf: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buf);

    cli.runClient(alloc.allocator(), &stdout_writer.interface, .{
        .host = app_args.host,
        .port = app_args.port,
        .query = app_args.query,
    }) catch |err| {
        std.debug.print("Program failed: {s}\n", .{@errorName(err)});
        std.process.exit(1);
    };
}
