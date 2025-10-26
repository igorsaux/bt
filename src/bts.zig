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

fn printUsage() void {
    std.debug.print("Usage: bts [--ip IP] [--port PORT] <MAPPING>\n", .{});
    std.debug.print("Example: bts --ip 127.0.0.1 --port 1234 \"?players\" 5 \"?status\" foobar\n", .{});
    std.debug.print("Options:\n", .{});
    std.debug.print("  --ip\tHost to listen on (default: 127.0.0.1)\n", .{});
    std.debug.print("  --port\tPort to listen on (default: 8888)\n", .{});
}

const Args = cli.ServerArgs;

pub fn main() !void {
    const alloc = std.heap.page_allocator;

    const args = try std.process.argsAlloc(alloc);
    defer std.process.argsFree(alloc, args);

    var parse_err: Args.Error = .{};
    const app_args = Args.parse(alloc, args, &parse_err) catch |err| {
        std.debug.print("{s}", .{@errorName(err)});

        if (parse_err.target) |target| {
            std.debug.print(": \"{s}\"", .{target});
        }

        std.debug.print("\n", .{});
        printUsage();
        std.process.exit(1);
    };

    if (app_args.mapping.items.len == 0) {
        printUsage();
        std.process.exit(1);
    }

    cli.runServer(alloc, .{
        .ip = app_args.ip orelse "127.0.0.1",
        .port = app_args.port orelse 8888,
        .mapping = app_args.mapping,
    }) catch |err| {
        std.debug.print("Program failed: {s}\n", .{@errorName(err)});
        std.process.exit(1);
    };
}
