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

/// Helper for parsing command-line arguments for the client tool.
///
/// `parse` validates argv and returns a populated ClientArgs on success.
pub const ClientArgs = struct {
    pub const Error = struct {
        target: ?[]const u8 = null,
    };
    pub const ParseError = error{ BadArgs, MissingAddress, InvalidAddress, MissingQuery, UnknownOption, MissingValue, InvalidValue, OutOfMemory };

    host: []const u8,
    port: u16,
    query: []const u8,

    /// Parse a host:port address string into (host, port).
    /// Returns ParseError.InvalidAddress for malformed input.
    fn parseAddress(arg: []const u8) ParseError!struct { []const u8, u16 } {
        const sep: usize = std.mem.indexOf(u8, arg, ":") orelse {
            return ParseError.InvalidAddress;
        };

        if (sep == 0 or sep >= arg.len - 1) {
            return ParseError.InvalidAddress;
        }

        const host = arg[0..sep];
        const port = std.fmt.parseInt(u16, arg[sep + 1 ..], 10) catch {
            return ParseError.InvalidAddress;
        };

        return .{ host, port };
    }

    /// Parse command-line arguments for the client.
    ///
    /// Expects argv style input and returns a ClientArgs on success.
    /// When err_out is provided it will be populated with the offending token on error.
    pub fn parse(args: []const []const u8, err_out: ?*Error) ParseError!@This() {
        if (args.len < 2) {
            return ParseError.MissingAddress;
        } else if (args.len < 3) {
            return ParseError.MissingQuery;
        }

        const host: []const u8, const port: u16 = try parseAddress(args[1]);
        const query: []const u8 = args[2];

        var i: usize = 3;

        while (i < args.len) {
            const arg: []const u8 = args[i];

            if (std.mem.startsWith(u8, arg, "--")) {
                if (err_out) |err| {
                    err.target = arg;
                }

                return ParseError.UnknownOption;
            }

            i += 1;
        }

        return .{
            .host = host,
            .port = port,
            .query = query,
        };
    }
};

test "Parse client args" {
    const args: []const []const u8 = &.{ "", "localhost:1234", "?status" };
    const client_args = try ClientArgs.parse(args, null);

    try std.testing.expectEqualStrings(client_args.host, "localhost");
    try std.testing.expectEqual(client_args.port, 1234);
    try std.testing.expectEqualStrings(client_args.query, "?status");
}

/// Options used to run the client.
pub const ClientOptions = struct {
    host: []const u8,
    port: u16,
    query: []const u8,
};

/// Execute the client: send a query and print the decoded response to `out`.
///
/// The function connects to the given host:port, writes an encoded request and
/// decodes the server response. Allocator is used for temporary allocations.
pub fn runClient(allocator: std.mem.Allocator, out: *std.Io.Writer, options: ClientOptions) !void {
    var request = try bt.EncodedRequest.init(allocator, options.query);
    defer request.deinit(allocator);

    var stream: std.net.Stream = try std.net.tcpConnectToHost(allocator, options.host, options.port);
    defer stream.close();

    var writer_buf: [1024]u8 = undefined;
    var writer: std.net.Stream.Writer = stream.writer(&writer_buf);

    try writer.interface.writeAll(request.data);
    try writer.interface.flush();

    var reader_buf: [1024]u8 = undefined;
    var reader: std.net.Stream.Reader = stream.reader(&reader_buf);

    var response = try bt.DecodedResponse.initStream(allocator, reader.interface());
    defer response.deinit(allocator);

    switch (response.object) {
        .string => {
            try out.print("{s}\n", .{response.object.string});
        },
        .number => {
            try out.print("{d}\n", .{response.object.number});
        },
        .null => {
            try out.print("null\n", .{});
        },
    }

    try out.flush();
}

/// A single mapping entry for the server: query -> response.
pub const Map = struct {
    query: []const u8,
    response: bt.Object,
};

/// Command-line argument parser for the server.
///
/// Parses mappings and optional --ip / --port flags.
pub const ServerArgs = struct {
    pub const Error = struct {
        target: ?[]const u8 = null,
    };
    pub const ParseError = error{ UnknownOption, MissingValue, InvalidValue, OutOfMemory };

    mapping: std.ArrayList(Map),
    ip: ?[]const u8,
    port: ?u16,

    /// Parse server CLI args into a ServerArgs value.
    /// The returned mapping owns memory allocated from `allocator` and must be deinitialized.
    pub fn parse(allocator: std.mem.Allocator, args: []const []const u8, err_out: ?*Error) ParseError!@This() {
        if (args.len <= 1) {
            return .{
                .mapping = try std.ArrayList(Map).initCapacity(allocator, 0),
                .ip = null,
                .port = null,
            };
        }

        var mapping = try std.ArrayList(Map).initCapacity(allocator, 8);
        var ip: ?[]const u8 = null;
        var port: ?u16 = null;

        var i: usize = 1;

        while (i < args.len) {
            const arg: []const u8 = args[i];

            if (std.mem.eql(u8, arg, "--port")) {
                if (i + 1 >= args.len) {
                    if (err_out) |err| {
                        err.target = arg;
                    }

                    return ParseError.MissingValue;
                }

                port = std.fmt.parseInt(u16, args[i + 1], 10) catch {
                    if (err_out) |err| {
                        err.target = args[i + 1];
                    }

                    return ParseError.InvalidValue;
                };

                i += 2;

                continue;
            } else if (std.mem.eql(u8, arg, "--ip")) {
                if (i + 1 >= args.len) {
                    if (err_out) |err| {
                        err.target = arg;
                    }

                    return ParseError.MissingValue;
                }

                ip = args[i + 1];
                i += 2;

                continue;
            } else if (std.mem.startsWith(u8, arg, "--")) {
                if (err_out) |err| {
                    err.target = arg;
                }

                return ParseError.UnknownOption;
            }

            if (i + 1 >= args.len) {
                if (err_out) |err| {
                    err.target = arg;
                }

                return ParseError.MissingValue;
            }

            var map: Map = .{
                .query = arg,
                .response = undefined,
            };

            if (std.fmt.parseFloat(f32, args[i + 1])) |val| {
                map.response = .{
                    .number = val,
                };
            } else |_| {
                map.response = .{
                    .string = args[i + 1],
                };
            }

            try mapping.append(allocator, map);

            i += 2;
        }

        return .{
            .mapping = mapping,
            .ip = ip,
            .port = port,
        };
    }

    pub fn deinit(this: *@This(), allocator: std.mem.Allocator) void {
        this.mapping.deinit(allocator);
    }
};

/// Options used to run the server.
pub const ServerOptions = struct {
    ip: []const u8,
    port: u16,
    mapping: std.ArrayList(Map),
};

/// Start the server and serve requests forever.
///
/// The function binds to options.ip:options.port and dispatches requests using
/// the provided mapping. Allocator is used for connection handling and buffers.
pub fn runServer(allocator: std.mem.Allocator, options: ServerOptions) !void {
    var stream: ?std.net.Stream = null;

    {
        var list: *std.net.AddressList = try std.net.getAddressList(allocator, options.ip, options.port);
        defer list.deinit();

        for (list.addrs) |addr| {
            const socket: std.posix.socket_t = std.posix.socket(addr.any.family, std.posix.SOCK.STREAM, std.posix.IPPROTO.TCP) catch {
                continue;
            };

            std.posix.bind(socket, &addr.any, addr.getOsSockLen()) catch {
                std.net.Stream.close(.{ .handle = socket });
                continue;
            };

            stream = .{ .handle = socket };

            break;
        }

        if (stream == null) {
            std.debug.print("Connection refused", .{});
            std.process.exit(1);
        }
    }

    defer stream.?.close();

    try std.posix.listen(stream.?.handle, 1);

    while (true) {
        const cl_sock: std.posix.socket_t = try std.posix.accept(stream.?.handle, null, null, 0);
        var cl_stream: std.net.Stream = .{ .handle = cl_sock };
        defer cl_stream.close();

        var request: bt.DecodedRequest = undefined;

        // read and decode the request
        {
            var stream_buf: [1024]u8 = undefined;
            var stream_reader: std.net.Stream.Reader = cl_stream.reader(&stream_buf);

            request = try bt.DecodedRequest.initStream(allocator, stream_reader.interface());
        }
        defer request.deinit(allocator);

        var map: ?Map = null;

        for (options.mapping.items) |i| {
            if (!std.mem.eql(u8, i.query, request.query)) {
                continue;
            }

            map = i;
            break;
        }

        var object: bt.Object = undefined;

        if (map) |m| {
            object = m.response;
        } else {
            object = .{ .null = .{} };
        }

        // encode and send the response
        {
            var response = try bt.EncodedResponse.init(allocator, object);
            defer response.deinit(allocator);

            var stream_buf: [1024]u8 = undefined;
            var stream_writer: std.net.Stream.Writer = cl_stream.writer(&stream_buf);

            try stream_writer.interface.writeAll(response.data);
            try stream_writer.interface.flush();
        }
    }
}

test "Parse server args" {
    const alloc = std.testing.allocator;

    const args: []const []const u8 = &.{ "", "--port", "1234", "--ip", "abc", "?status", "test", "?players", "5" };

    var server_args = try ServerArgs.parse(alloc, args, null);
    defer server_args.deinit(alloc);

    try std.testing.expectEqualStrings(server_args.ip.?, "abc");
    try std.testing.expectEqual(server_args.port.?, 1234);

    try std.testing.expectEqual(server_args.mapping.items.len, 2);

    const map1: Map = server_args.mapping.items[0];
    try std.testing.expectEqualStrings(map1.query, "?status");
    try std.testing.expectEqualStrings(map1.response.string, "test");

    const map2: Map = server_args.mapping.items[1];
    try std.testing.expectEqualStrings(map2.query, "?players");
    try std.testing.expectEqual(map2.response.number, 5);
}
