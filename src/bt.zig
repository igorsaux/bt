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

/// Magic bytes used as the fixed protocol prefix for every frame.
///
/// These two bytes identify messages on the wire and must appear at the start
/// of every encoded request or response.
pub const Magic: [2]u8 = .{ 0x00, 0x83 };
/// Integer type used to encode the size.
pub const SizeType = u16;
/// Fixed padding inserted after the size field.
pub const Padding = std.mem.zeroes([5]u8);

/// Discriminator for the payload object carried in a response.
pub const ObjectTag = enum(u8) {
    string = 0x06,
    number = 0x2A,
    null = 0x00,
};

/// In-memory representation of a protocol object.
///
/// Can be a string, a 32-bit floating point number, or null.
pub const Object = union(ObjectTag) {
    string: []const u8,
    number: f32,
    null: struct {},

    pub fn binarySize(this: @This()) usize {
        return switch (this) {
            .string => this.string.len,
            .number => @sizeOf(f32),
            .null => 0,
        };
    }
};

/// EncodedRequest holds the wire-format request bytes.
///
/// init allocates a buffer containing the full request frame; the caller is
/// responsible for releasing it with deinit.
pub const EncodedRequest = struct {
    pub const Error = error{ QueryTooLong, OutOfMemory };

    /// Binary data
    data: []u8,

    /// Build an encoded request from the given query bytes.
    /// On success returns an EncodedRequest with an owned buffer; caller must call deinit().
    pub fn init(allocator: std.mem.Allocator, query: []const u8) Error!@This() {
        if (query.len >= std.math.maxInt(SizeType)) {
            return Error.QueryTooLong;
        }

        const query_len: SizeType = @intCast(query.len);
        const size: u16, const ov: u1 = @addWithOverflow(@as(u16, @intCast(Padding.len + 1)), query_len);

        if (ov != 0) {
            return Error.QueryTooLong;
        }

        if (size == 0) {
            return .{ .data = &.{} };
        }

        const data: []u8 = try allocator.alloc(u8, Magic.len + @sizeOf(SizeType) + size);
        var writer: std.Io.Writer = std.Io.Writer.fixed(data);

        writer.writeAll(&Magic) catch unreachable;
        writer.writeInt(SizeType, size, .big) catch unreachable;
        writer.writeAll(&Padding) catch unreachable;
        writer.writeAll(query) catch unreachable;
        writer.writeByte(0) catch unreachable;

        return .{ .data = data };
    }

    pub fn deinit(this: *@This(), allocator: std.mem.Allocator) void {
        allocator.free(this.data);
    }
};

/// DecodedRequest represents a parsed request read from a stream.
///
/// initStream reads from an Io.Reader and allocates memory for the contained query.
pub const DecodedRequest = struct {
    pub const Error = error{ InvalidMagic, EndOfStream, ReadFailed, OutOfMemory };

    query: []u8,

    /// Read and decode a request frame from the provided stream reader.
    /// Allocates the returned query buffer which must be freed via deinit().
    pub fn initStream(allocator: std.mem.Allocator, stream: *std.Io.Reader) Error!@This() {
        var magic: @TypeOf(Magic) = undefined;
        try stream.readSliceAll(&magic);

        if (!std.mem.eql(u8, &magic, &Magic)) {
            return Error.InvalidMagic;
        }

        var size_buf: [@sizeOf(SizeType)]u8 = undefined;
        try stream.readSliceAll(&size_buf);
        try stream.discardAll(Padding.len);

        const size = std.mem.readInt(u16, &size_buf, .big);
        const query = try allocator.alloc(u8, size - Padding.len - 1);

        try stream.readSliceAll(query);

        return .{ .query = query };
    }

    pub fn deinit(this: *@This(), allocator: std.mem.Allocator) void {
        allocator.free(this.query);
    }
};

/// EncodedResponse contains a response serialized to the protocol wire format.
///
/// init allocates the encoded bytes; deinit frees the allocation.
pub const EncodedResponse = struct {
    pub const Error = error{ ResponseTooLong, OutOfMemory };

    data: []u8,

    /// Serialize an Object into a protocol response buffer.
    /// Returns ResponseTooLong when the object cannot fit into the size field.
    pub fn init(allocator: std.mem.Allocator, object: Object) Error!@This() {
        if (object.binarySize() > std.math.maxInt(SizeType) + 1) {
            return Error.ResponseTooLong;
        }

        const object_size: u16 = @intCast(object.binarySize());
        const size: u16 = object_size + 1;

        const data: []u8 = try allocator.alloc(u8, Magic.len + @sizeOf(SizeType) + @sizeOf(ObjectTag) + size);
        var writer: std.Io.Writer = std.Io.Writer.fixed(data);

        writer.writeAll(&Magic) catch unreachable;
        writer.writeInt(u16, size, .big) catch unreachable;
        writer.writeByte(@intFromEnum(object)) catch unreachable;

        switch (object) {
            .string => writer.writeAll(object.string) catch unreachable,
            .number => writer.writeAll(std.mem.asBytes(&object.number)) catch unreachable,
            else => {},
        }

        writer.writeByte(0) catch unreachable;

        return .{
            .data = data,
        };
    }

    pub fn deinit(this: *@This(), allocator: std.mem.Allocator) void {
        allocator.free(this.data);
    }
};

/// DecodedResponse is a parsed response read from a stream.
///
/// initStream reads the frame and returns an Object that may own allocated memory.
pub const DecodedResponse = struct {
    pub const Error = error{ InvalidMagic, InvalidObjectType, ReadFailed, EndOfStream, OutOfMemory };

    object: Object,

    /// Read and decode a response frame from the provided stream reader.
    /// The returned object may reference freshly allocated buffers that must be freed with deinit().
    pub fn initStream(allocator: std.mem.Allocator, stream: *std.Io.Reader) Error!@This() {
        var magic: @TypeOf(Magic) = undefined;
        try stream.readSliceAll(&magic);

        if (!std.mem.eql(u8, &magic, &Magic)) {
            return Error.InvalidMagic;
        }

        var size_buf: [@sizeOf(SizeType)]u8 = undefined;
        try stream.readSliceAll(&size_buf);

        const size: SizeType = std.mem.readInt(SizeType, &size_buf, .big);

        var tag_buf: [@sizeOf(ObjectTag)]u8 = undefined;
        try stream.readSliceAll(&tag_buf);

        const object_tag = std.enums.fromInt(ObjectTag, tag_buf[0]) orelse {
            return Error.InvalidObjectType;
        };

        var object: Object = undefined;

        switch (object_tag) {
            .string => {
                // without null
                const string_buf: []u8 = try allocator.alloc(u8, size - 1);
                try stream.readSliceAll(string_buf);

                object = .{ .string = string_buf };
            },
            .number => {
                var number_buf: [@sizeOf(f32)]u8 = undefined;
                try stream.readSliceEndian(u8, &number_buf, .little);

                object = .{ .number = std.mem.bytesToValue(f32, &number_buf) };
            },
            .null => {
                object = .{ .null = .{} };
            },
        }

        return .{
            .object = object,
        };
    }

    pub fn deinit(this: *@This(), allocator: std.mem.Allocator) void {
        switch (this.object) {
            .string => {
                allocator.free(this.object.string);
            },
            else => {
                return;
            },
        }
    }
};

test "Encode request" {
    const alloc = std.testing.allocator;

    var request = try EncodedRequest.init(alloc, "test");
    defer request.deinit(alloc);

    try std.testing.expectEqualSlices(u8, request.data, &.{ 0x00, 0x83, 0x00, 0x0A, 0x00, 0x00, 0x00, 0x00, 0x00, 0x74, 0x65, 0x73, 0x74, 0x00 });
}
