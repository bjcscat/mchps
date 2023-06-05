const std = @import("std");
const network = @import("./network.zig");
const varnum = @import("./varnum.zig");

pub fn main() !void {
    var allocator = std.heap.page_allocator;

    try network.init();
    defer network.deinit();

    var server = try network.Socket.create(.ipv4, .tcp);
    defer server.close();

    try server.bind(.{
        .address = .{ .ipv4 = network.Address.IPv4.loopback },
        .port = 25565,
    });

    try server.listen();
    std.log.info("listening at {}\n", .{try server.getLocalEndPoint()});

    while (true) {
        std.debug.print("Waiting for connection\n", .{});
        const client = try allocator.create(Client);
        client.* = Client{
            .conn = try server.accept(),
            .handle_frame = async client.handle(),
        };
    }
}

const Client = struct {
    conn: network.Socket,
    handle_frame: @Frame(Client.handle),

    fn handle(self: *Client) !void {
        try self.conn.writer().writeAll("server: welcome to the chat server\n");

        while (true) {
            var buf: [100]u8 = undefined;
            const amt = try self.conn.receive(&buf);
            if (amt == 0)
                break; // We're done, end of connection
            const msg = buf[0..amt];
            const packet_size = try varnum.readVarInt(msg);
            std.debug.print("Client wrote: {any} {any}\n", .{ packet_size, varnum.readVarInt(msg[@intCast(usize, packet_size)..]) });
        }
    }
};

test "Testing readVarInt" {
    try std.testing.expect(try varnum.readVarInt(&([_]u8{0x00})) == 0);
    try std.testing.expect(try varnum.readVarInt(&([_]u8{ 0x80, 0x01 })) == 128);
    try std.testing.expect(try varnum.readVarInt(&([_]u8{ 0xff, 0xff, 0xff, 0xff, 0x07 })) == 2147483647);
    try std.testing.expect(try varnum.readVarInt(&([_]u8{ 0xff, 0xff, 0xff, 0xff, 0x0f })) == -1);
}

test "Testing readVarLong" {
    try std.testing.expect(try varnum.readVarLong(&([_]u8{0x00})) == 0);
    try std.testing.expect(try varnum.readVarLong(&([_]u8{ 0x80, 0x01 })) == 128);
    try std.testing.expect(try varnum.readVarLong(&([_]u8{ 0xff, 0xff, 0xff, 0xff, 0x07 })) == 2147483647);
    try std.testing.expect(try varnum.readVarLong(&([_]u8{ 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0x7f })) == 9223372036854775807);
    try std.testing.expect(try varnum.readVarLong(&([_]u8{ 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0x01 })) == -1);
    try std.testing.expect(try varnum.readVarLong(&([_]u8{ 0x80, 0x80, 0x80, 0x80, 0xf8, 0xff, 0xff, 0xff, 0xff, 0x01 })) == -2147483648);
}
