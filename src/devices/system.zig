const std = @import("std");
const uxn = @import("../uxn.zig");

const GETVEC = uxn.GETVEC;
const Stack = uxn.Stack;
const Uxn = uxn.Uxn;
const uxn_eval = uxn.uxn_eval;

// static const char *errors[] = {
// 	"underflow",
// 	"overflow",
// 	"division by zero"};
const errors = [_][]const u8{ "underflow", "overflow", "division by zero" };

// static void
// system_print(Stack *s, char *name)
// {
// 	Uint8 i;
// 	fprintf(stderr, "<%s>", name);
// 	for(i = 0; i < s->ptr; i++)
// 		fprintf(stderr, " %02x", s->dat[i]);
// 	if(!i)
// 		fprintf(stderr, " empty");
// 	fprintf(stderr, "\n");
// }
fn system_print(s: *Stack, name: []const u8) void {
    std.debug.print("<{s}>", .{name});
    for (s.dat[0..s.ptr]) |s_dat|
        std.debug.print("{}", .{s_dat})
    else
        std.debug.print(" empty", .{});
    std.debug.print("\n", .{});
}

// void
// system_inspect(Uxn *u)
// {
// 	system_print(u->wst, "wst");
// 	system_print(u->rst, "rst");
// }
fn system_inspect(u: *Uxn) void {
    system_print(u.wst, "wst");
    system_print(u.rst, "rst");
}

// int
// uxn_halt(Uxn *u, Uint8 instr, Uint8 err, Uint16 addr)
// {
// 	Uint8 *d = &u->dev[0x00];
// 	Uint16 handler = GETVEC(d);
// 	if(handler) {
// 		u->wst->ptr = 4;
// 		u->wst->dat[0] = addr >> 0x8;
// 		u->wst->dat[1] = addr & 0xff;
// 		u->wst->dat[2] = instr;
// 		u->wst->dat[3] = err;
// 		return uxn_eval(u, handler);
// 	} else {
// 		system_inspect(u);
// 		fprintf(stderr, "%s %s, by %02x at 0x%04x.\n", (instr & 0x40) ? "Return-stack" : "Working-stack", errors[err - 1], instr, addr);
// 	}
// 	return 0;
// }
pub fn uxn_halt(u: *Uxn, instr: u8, err: u8, addr: u16) !void {
    const d = u.dev + 0x00;
    const handler = GETVEC(d);
    if (handler > 0) {
        u.wst.ptr = 4;
        u.wst.dat[0] = @intCast(u8, addr >> 0x8);
        u.wst.dat[1] = @intCast(u8, addr & 0xff);
        u.wst.dat[2] = instr;
        u.wst.dat[3] = err;
        return uxn_eval(u, handler);
    } else {
        system_inspect(u);
        std.debug.print("{s} {s}, by {} at {}.\n", .{ if (instr & 0x40 > 0) "Return-stack" else "Working-stack", errors[err - 1], instr, addr });
    }
}

// ** IO **

// void
// system_deo(Uxn *u, Uint8 *d, Uint8 port)
// {
// 	switch(port) {
// 	case 0x2: u->wst = (Stack *)(u->ram + (d[port] ? (d[port] * 0x100) : 0x10000)); break;
// 	case 0x3: u->rst = (Stack *)(u->ram + (d[port] ? (d[port] * 0x100) : 0x10100)); break;
// 	case 0xe:
// 		if(u->wst->ptr || u->rst->ptr) system_inspect(u);
// 		break;
// 	}
// }
pub fn system_deo(u: *Uxn, d: [*]u8, port: u8) void {
    // debug logging
    // std.debug.print("d: {*}, port: {}\n", .{ d, port });
    switch (port) {
        0x2 => u.wst = @ptrCast(*Stack, u.ram.ptr + if (d[port] > 0) @as(usize, d[port]) * 0x100 else 0x10000),
        0x3 => u.rst = @ptrCast(*Stack, u.ram.ptr + if (d[port] > 0) @as(usize, d[port]) * 0x100 else 0x10100),
        0xe => if (u.wst.ptr > 0 or u.rst.ptr > 0) system_inspect(u),
        // TODO: revisit
        else => {},
    }
}
