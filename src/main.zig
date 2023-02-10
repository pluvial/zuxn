const std = @import("std");
const datetime = @import("./devices/datetime.zig");
const file = @import("./devices/file.zig");
const system = @import("./devices/system.zig");
const uxn = @import("./uxn.zig");

const datetime_dei = datetime.datetime_dei;

const file_dei = file.file_dei;
const file_deo = file.file_deo;
const load_rom = file.load_rom;

const system_deo = system.system_deo;

const GETVEC = uxn.GETVEC;
const PAGE_PROGRAM = uxn.PAGE_PROGRAM;
const Uxn = uxn.Uxn;
const uxn_boot = uxn.uxn_boot;
const uxn_eval = uxn.uxn_eval;

// int
// main(int argc, char **argv)
// {
// 	Uxn u;
// 	int i;
// 	if(argc < 2)
// 		return emu_error("Usage", "uxncli game.rom args");
// 	if(!uxn_boot(&u, (Uint8 *)calloc(0x10300, sizeof(Uint8)), emu_dei, emu_deo))
// 		return emu_error("Boot", "Failed");
// 	if(!load_rom(&u, argv[1]))
// 		return emu_error("Load", "Failed");
// 	if(!uxn_eval(&u, PAGE_PROGRAM))
// 		return emu_error("Init", "Failed");
// 	for(i = 2; i < argc; i++) {
// 		char *p = argv[i];
// 		while(*p) console_input(&u, *p++);
// 		console_input(&u, '\n');
// 	}
// 	while(!u.dev[0x0f]) {
// 		int c = fgetc(stdin);
// 		if(c != EOF)
// 			console_input(&u, (Uint8)c);
// 	}
// 	return 0;
// }
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    var args_it = try std.process.argsWithAllocator(allocator);
    defer args_it.deinit();

    var args_list = std.ArrayList([]const u8).init(allocator);
    defer args_list.deinit();
    while (args_it.next()) |arg| {
        try args_list.append(arg);
    }
    const argv = args_list.items;
    const argc = args_list.items.len;

    if (argc < 2) return emu_error("Usage", "zuxn game.rom args");

    // debug logging;
    for (argv) |arg| {
        std.debug.print("{s} ", .{arg});
    }
    std.debug.print("\n", .{});

    const ram = try allocator.alloc(u8, 0x10300);
    defer allocator.free(ram);
    std.mem.set(u8, ram, 0);

    var u: Uxn = undefined;
    uxn_boot(&u, ram, emu_dei, emu_deo);

    if (try load_rom(&u, argv[1]) == 0) return emu_error("Load", "Failed");
    uxn_eval(&u, PAGE_PROGRAM) catch return emu_error("Init", "Failed");

    for (argv[2..]) |p| {
        for (p) |c| try console_input(&u, c);
        try console_input(&u, '\n');
    }
    const stdin = std.io.getStdIn().reader();
    while (u.dev[0x0f] == 0) {
        if (stdin.readByte()) |c|
            try console_input(&u, c)
        else |err| switch (err) {
            error.EndOfStream => {},
            else => return err,
        }
    }
}

// #define SUPPORT 0x1c03 /* devices mask */
const SUPPORT = 0x1c03;

// static int
// emu_error(char *msg, const char *err)
// {
// 	fprintf(stderr, "Error %s: %s\n", msg, err);
// 	return 0;
// }
fn emu_error(msg: []const u8, err: []const u8) void {
    std.debug.print("Error {s}: {s}\n", .{ msg, err });
}

// static int
// console_input(Uxn *u, char c)
// {
// 	Uint8 *d = &u->dev[0x10];
// 	d[0x02] = c;
// 	return uxn_eval(u, GETVEC(d));
// }
fn console_input(u: *Uxn, c: u8) !void {
    var d = u.dev + 0x10;
    d[0x02] = c;
    return uxn_eval(u, GETVEC(d));
}

// static void
// console_deo(Uint8 *d, Uint8 port)
// {
// 	FILE *fd = port == 0x8 ? stdout : port == 0x9 ? stderr
// 												  : 0;
// 	if(fd) {
// 		fputc(d[port], fd);
// 		fflush(fd);
// 	}
// }
fn console_deo(d: [*]u8, port: u8) void {
    const fd_writer = if (port == 0x8) std.io.getStdOut().writer() else if (port == 0x9) std.io.getStdErr().writer() else null;

    if (fd_writer) |writer| {
        writer.writeByte(d[port]) catch
            return std.debug.print("Failed to write to output port: {}\n", .{port});
    }
}

// static Uint8
// emu_dei(Uxn *u, Uint8 addr)
// {
// 	Uint8 p = addr & 0x0f, d = addr & 0xf0;
// 	switch(d) {
// 	case 0xa0: return file_dei(0, &u->dev[d], p);
// 	case 0xb0: return file_dei(1, &u->dev[d], p);
// 	case 0xc0: return datetime_dei(&u->dev[d], p);
// 	}
// 	return u->dev[addr];
// }
fn emu_dei(u: *Uxn, addr: u8) u8 {
    const p = addr & 0x0f;
    const d = addr & 0xf0;
    switch (d) {
        0xa0 => return file_dei(0, u.dev + d, p) catch |err| {
            std.debug.print("file_dei error: {s}\n", .{@errorName(err)});
            return std.math.maxInt(u8);
        },
        0xb0 => return file_dei(1, u.dev + d, p) catch |err| {
            std.debug.print("file_dei error: {s}\n", .{@errorName(err)});
            return std.math.maxInt(u8);
        },
        0xc0 => return datetime_dei(u.dev + d, p),
        // TODO: revisit
        else => unreachable,
    }
    return u.dev[addr];
}

// static void
// emu_deo(Uxn *u, Uint8 addr, Uint8 v)
// {
// 	Uint8 p = addr & 0x0f, d = addr & 0xf0;
// 	Uint16 mask = 0x1 << (d >> 4);
// 	u->dev[addr] = v;
// 	switch(d) {
// 	case 0x00: system_deo(u, &u->dev[d], p); break;
// 	case 0x10: console_deo(&u->dev[d], p); break;
// 	case 0xa0: file_deo(0, u->ram, &u->dev[d], p); break;
// 	case 0xb0: file_deo(1, u->ram, &u->dev[d], p); break;
// 	}
// 	if(p == 0x01 && !(SUPPORT & mask))
// 		fprintf(stderr, "Warning: Incompatible emulation, device: %02x.\n", d);
// }
fn emu_deo(u: *Uxn, addr: u8, v: u8) void {
    const p = addr & 0x0f;
    const d = addr & 0xf0;
    const mask = @as(u16, 0x1) << @intCast(u4, (d >> 4));
    u.dev[addr] = v;
    switch (d) {
        0x00 => system_deo(u, u.dev + d, p),
        0x10 => console_deo(u.dev + d, p),
        0xa0 => file_deo(0, u.ram, u.dev + d, p),
        0xb0 => file_deo(1, u.ram, u.dev + d, p),
        // TODO: revisit
        else => unreachable,
    }
    if (p == 0x01 and (SUPPORT & mask == 0))
        std.debug.print("Warning: Incompatible emulation, device: {}.\n", .{d});
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
