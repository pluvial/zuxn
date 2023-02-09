const std = @import("std");

// typedef unsigned char Uint8;
// typedef signed char Sint8;
// typedef unsigned short Uint16;
// typedef signed short Sint16;
// typedef unsigned int Uint32;

// #define PAGE_PROGRAM 0x0100
pub const PAGE_PROGRAM = 0x0100;

// #define GETVEC(d) ((d)[0] << 8 | (d)[1])
pub fn GETVEC(d: []u8) u16 {
    return d[0] << 8 | d[1];
}
// #define POKDEV(x, y) { d[(x)] = (y) >> 8; d[(x) + 1] = (y); }
pub fn POKDEV(x: u8, y: u16, d: [*]u8) void {
    d[x] = @intCast(u8, y >> 8);
    d[x + 1] = @intCast(u8, y);
}
// #define PEKDEV(o, x) { (o) = (d[(x)] << 8) + d[(x) + 1]; }
pub fn PEKDEV(o: *u16, x: u8, d: []u8) void {
    o.* = d[x] << 8 + d[x + 1];
}

// typedef struct {
// 	Uint8 dat[255], ptr;
// } Stack;
pub const Stack = struct {
    dat: [255]u8,
    ptr: u8,
};

// typedef struct Uxn {
// 	Uint8 *ram, *dev;
// 	Stack *wst, *rst;
// 	Uint8 (*dei)(struct Uxn *u, Uint8 addr);
// 	void (*deo)(struct Uxn *u, Uint8 addr, Uint8 value);
// } Uxn;
pub const Uxn = struct {
    ram: []u8,
    dev: [*]u8,
    wst: *Stack,
    rst: *Stack,
    dei: *const fn (u: *Uxn, addr: u8) u8,
    deo: *const fn (u: *Uxn, addr: u8, value: u8) void,
};

// typedef Uint8 Dei(Uxn *u, Uint8 addr);
pub const Dei = fn (u: *Uxn, addr: u8) u8;
// typedef void Deo(Uxn *u, Uint8 addr, Uint8 value);
pub const Deo = fn (u: *Uxn, addr: u8, value: u8) void;

// extern fn uxn_halt(u: *Uxn, instr: u8, err: u8, addr: u16) c_int;
const uxn_halt = @import("./devices/system.zig").uxn_halt;

// #define HALT(c) { return uxn_halt(u, instr, (c), pc - 1); }
pub fn HALT(c: u8, u: *Uxn, instr: u8, pc: u16) c_int {
    return uxn_halt(u, instr, c, pc - 1);
}
// #define JUMP(x) { if(bs) pc = (x); else pc += (Sint8)(x); }
pub fn JUMP(x: u16, bs: u16, pc: *u16) void {
    if (bs > 0) pc.* = x else pc.* += @intCast(i8, x);
}
// #define PUSH8(s, x) { if(s->ptr == 0xff) HALT(2) s->dat[s->ptr++] = (x); }
pub fn PUSH8(s: *Stack, x: u8, u: *Uxn, instr: u8, pc: u16) c_int {
    if (s.ptr == 0xff) return HALT(2, u, instr, pc);
    s.dat[s.ptr] = x;
    s.ptr += 1;
}
// #define PUSH16(s, x) { if((j = s->ptr) >= 0xfe) HALT(2) k = (x); s->dat[j] = k >> 8; s->dat[j + 1] = k; s->ptr = j + 2; }
pub fn PUSH16(s: *Stack, x: u8, j: *u16, k: *u16, u: *Uxn, instr: u8, pc: u16) c_int {
    j.* = s.ptr;
    if (j.* >= 0xfe) return HALT(2, u, instr, pc);
    k.* = x;
    s.dat[j.*] = x >> 8;
    s.dat[j.* + 1] = x;
    s.ptr = j.* + 2;
}
// #define PUSH(s, x) { if(bs) { PUSH16(s, (x)) } else { PUSH8(s, (x)) } }
pub fn PUSH(s: *Stack, x: u8, j: *u16, k: *u16, u: *Uxn, instr: u8, pc: u16, bs: u16) c_int {
    if (bs > 0)
        return PUSH16(s, x, j, k, u, instr, pc)
    else
        return PUSH8(s, x, u, instr, pc);
}
// #define POP8(o) { if(!(j = *sp)) HALT(1) o = (Uint16)src->dat[--j]; *sp = j; }
pub fn POP8(o: *u16, src: Stack, j: *u16, u: *Uxn, instr: u8, pc: u16, sp: *u8) ?c_int {
    j.* = sp.*;
    if (j.* == 0) return HALT(1, u, instr, pc);
    j.* -= 1;
    o.* = src.dat[j.*];
    sp.* = @intCast(u8, j.*);
    // TODO: revisit
    return null;
}
// #define POP16(o) { if((j = *sp) <= 1) HALT(1) o = (src->dat[j - 2] << 8) + src->dat[j - 1]; *sp = j - 2; }
pub fn POP16(o: *u16, src: Stack, j: *u16, u: *Uxn, instr: u8, pc: u16, sp: *u8) ?c_int {
    j.* = sp.*;
    if (j <= 1) return HALT(1, u, instr, pc);
    o.* = (src.dat[j.* - 2] << 8) + src.dat[j.* - 1];
    sp.* = j.* - 2;
    // TODO: revisit
    return null;
}
// #define POP(o) { if(bs) { POP16(o) } else { POP8(o) } }
pub fn POP(o: *u16, src: Stack, j: *u16, u: *Uxn, instr: u8, pc: u16, sp: *u8, bs: u16) ?c_int {
    if (bs > 0)
        return POP16(o, src, j, u, instr, pc, sp, bs)
    else
        return POP8(o, src, j, u, instr, pc, sp, bs);
}
// #define POKE(x, y) { if(bs) { u->ram[(x)] = (y) >> 8; u->ram[(x) + 1] = (y); } else { u->ram[(x)] = y; } }
pub fn POKE(x: u16, y: u16, u: *Uxn, bs: u16) void {
    if (bs > 0) {
        u.ram[x] = y >> 8;
        u.ram[x + 1] = y;
    } else {
        u.ram[x] = y;
    }
}
// #define PEEK16(o, x) { o = (u->ram[(x)] << 8) + u->ram[(x) + 1]; }
pub fn PEEK16(o: *u16, x: u16, u: *Uxn) void {
    o.* = (u.ram[x] << 8) + u.ram[x + 1];
}
// #define PEEK(o, x) { if(bs) PEEK16(o, x) else o = u->ram[(x)]; }
pub fn PEEK(o: *u16, x: u16, u: *Uxn, bs: u16) void {
    if (bs > 0)
        PEEK16(o, x, u, bs)
    else
        o.* = u.ram[x];
}
// #define DEVR(o, x) { o = u->dei(u, x); if (bs) o = (o << 8) + u->dei(u, (x) + 1); }
pub fn DEVR(o: *u16, x: u16, u: *Uxn, bs: u16) void {
    o.* = u.dei(u, x);
    if (bs > 0)
        o.* = (o.* << 8) + u.dei(u, x + 1);
}
// #define DEVW(x, y) { if (bs) { u->deo(u, (x), (y) >> 8); u->deo(u, (x) + 1, (y)); } else { u->deo(u, x, (y)); } }
pub fn DEVW(x: u16, y: u16, u: *Uxn, bs: u16) void {
    if (bs > 0) {
        u.deo(u, x, y >> 8);
        u.deo(u, x + 1, y);
    } else {
        u.deo(u, x, y);
    }
}

// int
// uxn_eval(Uxn *u, Uint16 pc)
// {
// 	Uint8 kptr, *sp;
// 	Uint16 a, b, c, j, k, bs, instr, opcode;
// 	Stack *src, *dst;
// 	if(!pc || u->dev[0x0f]) return 0;
// 	for(;;) {
// 		instr = u->ram[pc++];
// 		/* Return Mode */
// 		if(instr & 0x40) { src = u->rst; dst = u->wst; }
// 		else { src = u->wst; dst = u->rst; }
// 		/* Keep Mode */
// 		if(instr & 0x80) { kptr = src->ptr; sp = &kptr; }
// 		else sp = &src->ptr;
// 		/* Short Mode */
// 		bs = instr & 0x20;
// 		opcode = instr & 0x1f;
// 		switch(opcode - (!opcode * (instr >> 5))) {
// 		/* Literals/Calls */
// 		case -0x0: /* BRK */ return 1;
// 		case -0x1: /* JCI */ POP8(b) if(!b) { pc += 2; break; }
// 		case -0x2: /* JMI */ PEEK16(a, pc) pc += a + 2; break;
// 		case -0x3: /* JSI */ PUSH16(u->rst, pc + 2) PEEK16(a, pc) pc += a + 2; break;
// 		case -0x4: /* LIT */
// 		case -0x6: /* LITr */ a = u->ram[pc++]; PUSH8(src, a) break;
// 		case -0x5: /* LIT2 */
// 		case -0x7: /* LIT2r */ PEEK16(a, pc) PUSH16(src, a) pc += 2; break;
// 		/* ALU */
// 		case 0x01: /* INC */ POP(a) PUSH(src, a + 1) break;
// 		case 0x02: /* POP */ POP(a) break;
// 		case 0x03: /* NIP */ POP(a) POP(b) PUSH(src, a) break;
// 		case 0x04: /* SWP */ POP(a) POP(b) PUSH(src, a) PUSH(src, b) break;
// 		case 0x05: /* ROT */ POP(a) POP(b) POP(c) PUSH(src, b) PUSH(src, a) PUSH(src, c) break;
// 		case 0x06: /* DUP */ POP(a) PUSH(src, a) PUSH(src, a) break;
// 		case 0x07: /* OVR */ POP(a) POP(b) PUSH(src, b) PUSH(src, a) PUSH(src, b) break;
// 		case 0x08: /* EQU */ POP(a) POP(b) PUSH8(src, b == a) break;
// 		case 0x09: /* NEQ */ POP(a) POP(b) PUSH8(src, b != a) break;
// 		case 0x0a: /* GTH */ POP(a) POP(b) PUSH8(src, b > a) break;
// 		case 0x0b: /* LTH */ POP(a) POP(b) PUSH8(src, b < a) break;
// 		case 0x0c: /* JMP */ POP(a) JUMP(a) break;
// 		case 0x0d: /* JCN */ POP(a) POP8(b) if(b) JUMP(a) break;
// 		case 0x0e: /* JSR */ POP(a) PUSH16(dst, pc) JUMP(a) break;
// 		case 0x0f: /* STH */ POP(a) PUSH(dst, a) break;
// 		case 0x10: /* LDZ */ POP8(a) PEEK(b, a) PUSH(src, b) break;
// 		case 0x11: /* STZ */ POP8(a) POP(b) POKE(a, b) break;
// 		case 0x12: /* LDR */ POP8(a) b = pc + (Sint8)a; PEEK(c, b) PUSH(src, c) break;
// 		case 0x13: /* STR */ POP8(a) POP(b) c = pc + (Sint8)a; POKE(c, b) break;
// 		case 0x14: /* LDA */ POP16(a) PEEK(b, a) PUSH(src, b) break;
// 		case 0x15: /* STA */ POP16(a) POP(b) POKE(a, b) break;
// 		case 0x16: /* DEI */ POP8(a) DEVR(b, a) PUSH(src, b) break;
// 		case 0x17: /* DEO */ POP8(a) POP(b) DEVW(a, b) break;
// 		case 0x18: /* ADD */ POP(a) POP(b) PUSH(src, b + a) break;
// 		case 0x19: /* SUB */ POP(a) POP(b) PUSH(src, b - a) break;
// 		case 0x1a: /* MUL */ POP(a) POP(b) PUSH(src, (Uint32)b * a) break;
// 		case 0x1b: /* DIV */ POP(a) POP(b) if(!a) HALT(3) PUSH(src, b / a) break;
// 		case 0x1c: /* AND */ POP(a) POP(b) PUSH(src, b & a) break;
// 		case 0x1d: /* ORA */ POP(a) POP(b) PUSH(src, b | a) break;
// 		case 0x1e: /* EOR */ POP(a) POP(b) PUSH(src, b ^ a) break;
// 		case 0x1f: /* SFT */ POP8(a) POP(b) PUSH(src, b >> (a & 0x0f) << ((a & 0xf0) >> 4)) break;
// 		}
// 	}
// }
pub fn uxn_eval(u: *Uxn, _pc: u16) !c_int {
    var pc = _pc;
    var kptr: u8 = undefined;
    var sp: *u8 = undefined;
    // var a: u16 = undefined;
    var b: u16 = undefined;
    // var c: u16 = undefined;
    var j: u16 = undefined;
    // var k: u16 = undefined;
    var bs: u16 = undefined;
    var instr: u16 = undefined;
    var opcode: u16 = undefined;
    var src: *Stack = undefined;
    var dst: *Stack = undefined;
    if (pc == 0 or u.dev[0x0f] > 0) return 0;
    while (true) {
        instr = u.ram[pc];
        pc += 1;
        //  Return Mode
        if (instr & 0x40 != 0) {
            src = u.rst;
            dst = u.wst;
        } else {
            src = u.wst;
            dst = u.rst;
        }
        //  Keep Mode
        if (instr & 0x80 != 0) {
            kptr = src.ptr;
            sp = &kptr;
        } else sp = &src.ptr;
        // Short Mode
        bs = instr & 0x20;
        opcode = instr & 0x1f;
        switch (@intCast(i32, opcode - (@boolToInt(opcode == 0) * (instr >> 5)))) {
            // Literals/Calls
            -0x0 => return 1, // BRK
            -0x1 => { // JCI
                if (POP8(&b, src.*, &j, u, @intCast(u8, instr), pc, sp)) |err| return err;
                if (b > 0) {
                    pc += 2;
                }
            },
            // TODO: revisit
            else => unreachable,
            // 		case -0x0: /* BRK */ return 1;
            // 		case -0x1: /* JCI */ POP8(b) if(!b) { pc += 2; break; }
            // 		case -0x2: /* JMI */ PEEK16(a, pc) pc += a + 2; break;
            // 		case -0x3: /* JSI */ PUSH16(u->rst, pc + 2) PEEK16(a, pc) pc += a + 2; break;
            // 		case -0x4: /* LIT */
            // 		case -0x6: /* LITr */ a = u->ram[pc++]; PUSH8(src, a) break;
            // 		case -0x5: /* LIT2 */
            // 		case -0x7: /* LIT2r */ PEEK16(a, pc) PUSH16(src, a) pc += 2; break;
            // 		/* ALU */
            // 		case 0x01: /* INC */ POP(a) PUSH(src, a + 1) break;
            // 		case 0x02: /* POP */ POP(a) break;
            // 		case 0x03: /* NIP */ POP(a) POP(b) PUSH(src, a) break;
            // 		case 0x04: /* SWP */ POP(a) POP(b) PUSH(src, a) PUSH(src, b) break;
            // 		case 0x05: /* ROT */ POP(a) POP(b) POP(c) PUSH(src, b) PUSH(src, a) PUSH(src, c) break;
            // 		case 0x06: /* DUP */ POP(a) PUSH(src, a) PUSH(src, a) break;
            // 		case 0x07: /* OVR */ POP(a) POP(b) PUSH(src, b) PUSH(src, a) PUSH(src, b) break;
            // 		case 0x08: /* EQU */ POP(a) POP(b) PUSH8(src, b == a) break;
            // 		case 0x09: /* NEQ */ POP(a) POP(b) PUSH8(src, b != a) break;
            // 		case 0x0a: /* GTH */ POP(a) POP(b) PUSH8(src, b > a) break;
            // 		case 0x0b: /* LTH */ POP(a) POP(b) PUSH8(src, b < a) break;
            // 		case 0x0c: /* JMP */ POP(a) JUMP(a) break;
            // 		case 0x0d: /* JCN */ POP(a) POP8(b) if(b) JUMP(a) break;
            // 		case 0x0e: /* JSR */ POP(a) PUSH16(dst, pc) JUMP(a) break;
            // 		case 0x0f: /* STH */ POP(a) PUSH(dst, a) break;
            // 		case 0x10: /* LDZ */ POP8(a) PEEK(b, a) PUSH(src, b) break;
            // 		case 0x11: /* STZ */ POP8(a) POP(b) POKE(a, b) break;
            // 		case 0x12: /* LDR */ POP8(a) b = pc + (Sint8)a; PEEK(c, b) PUSH(src, c) break;
            // 		case 0x13: /* STR */ POP8(a) POP(b) c = pc + (Sint8)a; POKE(c, b) break;
            // 		case 0x14: /* LDA */ POP16(a) PEEK(b, a) PUSH(src, b) break;
            // 		case 0x15: /* STA */ POP16(a) POP(b) POKE(a, b) break;
            // 		case 0x16: /* DEI */ POP8(a) DEVR(b, a) PUSH(src, b) break;
            // 		case 0x17: /* DEO */ POP8(a) POP(b) DEVW(a, b) break;
            // 		case 0x18: /* ADD */ POP(a) POP(b) PUSH(src, b + a) break;
            // 		case 0x19: /* SUB */ POP(a) POP(b) PUSH(src, b - a) break;
            // 		case 0x1a: /* MUL */ POP(a) POP(b) PUSH(src, (Uint32)b * a) break;
            // 		case 0x1b: /* DIV */ POP(a) POP(b) if(!a) HALT(3) PUSH(src, b / a) break;
            // 		case 0x1c: /* AND */ POP(a) POP(b) PUSH(src, b & a) break;
            // 		case 0x1d: /* ORA */ POP(a) POP(b) PUSH(src, b | a) break;
            // 		case 0x1e: /* EOR */ POP(a) POP(b) PUSH(src, b ^ a) break;
            // 		case 0x1f: /* SFT */ POP8(a) POP(b) PUSH(src, b >> (a & 0x0f) << ((a & 0xf0) >> 4)) break;
        }
    }
}

// int
// uxn_boot(Uxn *u, Uint8 *ram, Dei *dei, Deo *deo)
// {
// 	Uint32 i;
// 	char *cptr = (char *)u;
// 	for(i = 0; i < sizeof(*u); i++)
// 		cptr[i] = 0x00;
// 	u->wst = (Stack *)(ram + 0x10000);
// 	u->rst = (Stack *)(ram + 0x10100);
// 	u->dev = (Uint8 *)(ram + 0x10200);
// 	u->ram = ram;
// 	u->dei = dei;
// 	u->deo = deo;
// 	return 1;
// }
pub fn uxn_boot(u: *Uxn, ram: []u8, dei: *const Dei, deo: *const Deo) !void {
    std.mem.set(u8, std.mem.asBytes(u), 0);
    u.wst = @ptrCast(*Stack, ram.ptr + 0x10000);
    u.rst = @ptrCast(*Stack, ram.ptr + 0x10100);
    u.dev = ram.ptr + 0x10200;
    u.ram = ram;
    u.dei = dei;
    u.deo = deo;
}
