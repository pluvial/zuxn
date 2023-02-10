const std = @import("std");
const uxn = @import("../uxn.zig");

const PAGE_PROGRAM = uxn.PAGE_PROGRAM;
const PEKDEV = uxn.PEKDEV;
const POKDEV = uxn.POKDEV;
const Uxn = uxn.Uxn;

// #define PATH_MAX 4096
const PATH_MAX = 4096;

// #define POLYFILEY 2
const POLYFILEY = 2;
// #define DEV_FILE0 0xa
const DEV_FILE0 = 0xa;

// typedef struct {
// 	FILE *f;
// 	DIR *dir;
// 	char current_filename[4096];
// 	struct dirent *de;
// 	enum { IDLE,
// 		FILE_READ,
// 		FILE_WRITE,
// 		DIR_READ } state;
// 	int outside_sandbox;
// } UxnFile;
const UxnFile = struct {
    f: ?std.fs.File,
    // dir: ?std.fs.Dir,
    dir: ?std.fs.IterableDir,
    buffer_filename: [4096]u8,
    current_filename: []u8,
    de: ?std.fs.IterableDir.Entry,
    state: enum {
        IDLE,
        FILE_READ,
        FILE_WRITE,
        DIR_READ,
    },
    outside_sandbox: bool,
};

// static UxnFile uxn_file[POLYFILEY];
var uxn_file: [POLYFILEY]UxnFile = undefined;

// static void
// reset(UxnFile *c)
// {
// 	if(c->f != NULL) {
// 		fclose(c->f);
// 		c->f = NULL;
// 	}
// 	if(c->dir != NULL) {
// 		closedir(c->dir);
// 		c->dir = NULL;
// 	}
// 	c->de = NULL;
// 	c->state = IDLE;
// 	c->outside_sandbox = 0;
// }
fn reset(c: *UxnFile) void {
    if (c.f != null) {
        c.f.?.close();
        c.f = null;
    }
    if (c.dir != null) {
        c.dir.?.close();
        c.dir = null;
    }
    c.de = null;
    c.state = .IDLE;
    c.outside_sandbox = false;
}

// static Uint16
// get_entry(char *p, Uint16 len, const char *pathname, const char *basename, int fail_nonzero)
// {
// 	struct stat st;
// 	if(len < strlen(basename) + 7)
// 		return 0;
// 	if(stat(pathname, &st))
// 		return fail_nonzero ? sprintf(p, "!!!! %s\n", basename) : 0;
// 	else if(S_ISDIR(st.st_mode))
// 		return sprintf(p, "---- %s\n", basename);
// 	else if(st.st_size < 0x10000)
// 		return sprintf(p, "%04x %s\n", (unsigned int)st.st_size, basename);
// 	else
// 		return sprintf(p, "???? %s\n", basename);
// }
fn get_entry(p: []u8, pathname: []const u8, basename: []const u8, fail_nonzero: bool) !u16 {
    if (p.len < basename.len + 7)
        return error.BufferTooSmall;
    const st = std.fs.cwd().statFile(pathname) catch
        return if (fail_nonzero) @intCast(u16, (try std.fmt.bufPrint(p, "!!!! {s}\n", .{basename})).len) else 0;
    const str = if (st.kind == .Directory)
        try std.fmt.bufPrint(p, "---- {s}\n", .{basename})
    else if (st.size < 0x10000)
        try std.fmt.bufPrint(p, "{} {s}\n", .{ st.size, basename })
    else
        try std.fmt.bufPrint(p, "???? {s}\n", .{basename});
    return @intCast(u16, str.len);
}

// static Uint16
// file_read_dir(UxnFile *c, char *dest, Uint16 len)
// {
// 	static char pathname[4352];
// 	char *p = dest;
// 	if(c->de == NULL) c->de = readdir(c->dir);
// 	for(; c->de != NULL; c->de = readdir(c->dir)) {
// 		Uint16 n;
// 		if(c->de->d_name[0] == '.' && c->de->d_name[1] == '\0')
// 			continue;
// 		if(strcmp(c->de->d_name, "..") == 0) {
// 			/* hide "sandbox/.." */
// 			char cwd[PATH_MAX] = {'\0'}, t[PATH_MAX] = {'\0'};
// 			/* Note there's [currently] no way of chdir()ing from uxn, so $PWD
// 			 * is always the sandbox top level. */
// 			getcwd(cwd, sizeof(cwd));
// 			/* We already checked that c->current_filename exists so don't need a wrapper. */
// 			realpath(c->current_filename, t);
// 			if(strcmp(cwd, t) == 0)
// 				continue;
// 		}
// 		if(strlen(c->current_filename) + 1 + strlen(c->de->d_name) < sizeof(pathname))
// 			sprintf(pathname, "%s/%s", c->current_filename, c->de->d_name);
// 		else
// 			pathname[0] = '\0';
// 		n = get_entry(p, len, pathname, c->de->d_name, 1);
// 		if(!n) break;
// 		p += n;
// 		len -= n;
// 	}
// 	return p - dest;
// }
fn file_read_dir(c: *UxnFile, dest: []u8, len_: u16) !u16 {
    var len = len_;
    const S = struct {
        const size = 4352;
        var pathname: [size]u8 = undefined;
    };
    var p = dest.ptr;
    var it = c.dir.?.iterate();
    if (c.de == null) c.de = try it.next();
    while (c.de) |de| : (c.de = try it.next()) {
        if (de.name.len == 1 and de.name[0] == '.')
            continue;
        if (std.mem.eql(u8, de.name, "..")) {
            var cwd_buf: [PATH_MAX]u8 = undefined;
            const cwd = try std.os.getcwd(&cwd_buf);
            var t_buf: [PATH_MAX]u8 = undefined;
            const t = try std.os.realpath(c.current_filename, t_buf[0..1024]);
            if (std.mem.eql(u8, cwd, t))
                continue;
        }
        const pathname = if (c.current_filename.len + de.name.len < S.size)
            try std.fmt.bufPrint(&S.pathname, "{s}/{s}", .{ c.current_filename, de.name })
        else
            "";
        const n = try get_entry(p[0..len], pathname, de.name, true);
        if (n == 0) break;
        p += n;
        len -= n;
    }
    return @intCast(u16, @ptrToInt(p) - @ptrToInt(dest.ptr));
}

// static char *
// retry_realpath(const char *file_name)
// {
// 	char r[PATH_MAX] = {'\0'}, p[PATH_MAX] = {'\0'}, *x;
// 	if(file_name == NULL) {
// 		errno = EINVAL;
// 		return NULL;
// 	} else if(strlen(file_name) >= PATH_MAX) {
// 		errno = ENAMETOOLONG;
// 		return NULL;
// 	}
// 	if(file_name[0] != '/') {
// 		/* TODO: use a macro instead of '/' for absolute path first character so that other systems can work */
// 		/* if a relative path, prepend cwd */
// 		getcwd(p, sizeof(p));
// 		strcat(p, "/"); /* TODO: use a macro instead of '/' for the path delimiter */
// 	}
// 	strcat(p, file_name);
// 	while(realpath(p, r) == NULL) {
// 		if(errno != ENOENT)
// 			return NULL;
// 		x = strrchr(p, '/'); /* TODO: path delimiter macro */
// 		if(x)
// 			*x = '\0';
// 		else
// 			return NULL;
// 	}
// 	x = malloc(strlen(r) + 1);
// 	strcpy(x, r);
// 	return x;
// }
fn retry_realpath(file_name: ?[]const u8) !?[]const u8 {
    // if (file_name == null)
    //     return error.BadPathName
    // else if (file_name >= PATH_MAX)
    //     return error.NameTooLong;
    // var p: [PATH_MAX]u8 = undefined;
    // var x: *u8 = undefined;
    // if (file_name[0] != '/') {
    //     const cwd = std.os.getcwd(p);
    //     p[cwd.len] = '/';
    // }
    // var r: [PATH_MAX]u8 = undefined;
    // while (std.os.realpath(p, r) catch |err| switch (err) {
    //     error.FileNotFound => null,
    //     else => return null,
    // }) |rp| {

    // }
    return file_name;
}

// static void
// file_check_sandbox(UxnFile *c)
// {
// 	char *x, *rp, cwd[PATH_MAX] = {'\0'};
// 	x = getcwd(cwd, sizeof(cwd));
// 	rp = retry_realpath(c->current_filename);
// 	if(rp == NULL || (x && strncmp(cwd, rp, strlen(cwd)) != 0)) {
// 		c->outside_sandbox = 1;
// 		fprintf(stderr, "file warning: blocked attempt to access %s outside of sandbox\n", c->current_filename);
// 	}
// 	free(rp);
// }
fn file_check_sandbox(c: *UxnFile) !void {
    var buffer: [PATH_MAX]u8 = undefined;
    const cwd = try std.os.getcwd(&buffer);
    const rp = std.fs.cwd().realpath(c.current_filename, &buffer) catch null;
    if (rp == null or !std.mem.eql(u8, cwd, rp.?)) {
        c.outside_sandbox = true;
        std.debug.print("file warning: blocked attempt to access {s} outside of sandbox\n", .{c.current_filename});
    }
}

// static Uint16
// file_init(UxnFile *c, char *filename, size_t max_len, int override_sandbox)
// {
// 	char *p = c->current_filename;
// 	size_t len = sizeof(c->current_filename);
// 	reset(c);
// 	if(len > max_len) len = max_len;
// 	while(len) {
// 		if((*p++ = *filename++) == '\0') {
// 			if(!override_sandbox) /* override sandbox for loading roms */
// 				file_check_sandbox(c);
// 			return 0;
// 		}
// 		len--;
// 	}
// 	c->current_filename[0] = '\0';
// 	return 0;
// }
fn file_init(c: *UxnFile, filename: []const u8, override_sandbox: bool) !void {
    reset(c);
    c.current_filename = c.buffer_filename[0..filename.len];
    std.mem.copy(u8, c.current_filename, filename);
    if (!override_sandbox)
        try file_check_sandbox(c);
}

// static Uint16
// file_read(UxnFile *c, void *dest, Uint16 len)
// {
// 	if(c->outside_sandbox) return 0;
// 	if(c->state != FILE_READ && c->state != DIR_READ) {
// 		reset(c);
// 		if((c->dir = opendir(c->current_filename)) != NULL)
// 			c->state = DIR_READ;
// 		else if((c->f = fopen(c->current_filename, "rb")) != NULL)
// 			c->state = FILE_READ;
// 	}
// 	if(c->state == FILE_READ)
// 		return fread(dest, 1, len, c->f);
// 	if(c->state == DIR_READ)
// 		return file_read_dir(c, dest, len);
// 	return 0;
// }
fn file_read(c: *UxnFile, dest: []u8, len: u16) !u16 {
    if (c.outside_sandbox) return 0;
    if (c.state != .FILE_READ and c.state != .DIR_READ) {
        reset(c);
        // c.dir = std.fs.cwd().openDir(c.current_filename, .{}) catch null;
        c.dir = std.fs.cwd().openIterableDir(c.current_filename, .{}) catch null;
        if (c.dir != null)
            c.state = .DIR_READ
        else {
            c.f = std.fs.cwd().openFile(c.current_filename, .{}) catch null;
            if (c.f != null)
                c.state = .FILE_READ;
        }
    }
    if (c.state == .FILE_READ)
        return @intCast(u16, try c.f.?.reader().readAtLeast(dest, len));
    if (c.state == .DIR_READ)
        return try file_read_dir(c, dest, len);
    return 0;
}

// static Uint16
// file_write(UxnFile *c, void *src, Uint16 len, Uint8 flags)
// {
// 	Uint16 ret = 0;
// 	if(c->outside_sandbox) return 0;
// 	if(c->state != FILE_WRITE) {
// 		reset(c);
// 		if((c->f = fopen(c->current_filename, (flags & 0x01) ? "ab" : "wb")) != NULL)
// 			c->state = FILE_WRITE;
// 	}
// 	if(c->state == FILE_WRITE) {
// 		if((ret = fwrite(src, 1, len, c->f)) > 0 && fflush(c->f) != 0)
// 			ret = 0;
// 	}
// 	return ret;
// }
fn file_write(c: *UxnFile, src: []u8, flags: u8) !void {
    if (c.outside_sandbox) return error.OutsideSandbox;
    if (c.state != .FILE_WRITE) {
        reset(c);
        c.f = std.fs.cwd().openFile(c.current_filename, .{ .mode = .read_write }) catch null;
        if (c.f != null)
            c.state = .FILE_WRITE;
    }
    if (c.state == .FILE_WRITE) {
        const append = flags & 0x01 != 0;
        if (append) try c.f.?.seekFromEnd(0);
        try c.f.?.writer().writeAll(src);
    }
}

// static Uint16
// file_stat(UxnFile *c, void *dest, Uint16 len)
// {
// 	char *basename = strrchr(c->current_filename, '/');
// 	if(c->outside_sandbox) return 0;
// 	if(basename != NULL)
// 		basename++;
// 	else
// 		basename = c->current_filename;
// 	return get_entry(dest, len, c->current_filename, basename, 0);
// }
// static Uint16
// file_stat(UxnFile *c, void *dest, Uint16 len)
fn file_stat(c: *UxnFile, dest: []u8) !u16 {
    if (c.outside_sandbox) return 0;
    const basename_index = if (std.mem.lastIndexOfScalar(u8, c.current_filename, '/')) |index|
        index + 1
    else
        0;
    const basename = c.current_filename[basename_index..];
    return get_entry(dest, c.current_filename, basename, false);
}

// static Uint16
// file_delete(UxnFile *c)
// {
// 	return c->outside_sandbox ? 0 : unlink(c->current_filename);
// }
fn file_delete(c: *UxnFile) !void {
    if (c.outside_sandbox)
        return error.OutsideSandbox
    else
        try std.fs.cwd().deleteFile(c.current_filename);
}

// ** IO **

// void
// file_deo(Uint8 id, Uint8 *ram, Uint8 *d, Uint8 port)
// {
// 	UxnFile *c = &uxn_file[id];
// 	Uint16 addr, len, res;
// 	switch(port) {
// 	case 0x5:
// 		PEKDEV(addr, 0x4);
// 		PEKDEV(len, 0xa);
// 		if(len > 0x10000 - addr)
// 			len = 0x10000 - addr;
// 		res = file_stat(c, &ram[addr], len);
// 		POKDEV(0x2, res);
// 		break;
// 	case 0x6:
// 		res = file_delete(c);
// 		POKDEV(0x2, res);
// 		break;
// 	case 0x9:
// 		PEKDEV(addr, 0x8);
// 		res = file_init(c, (char *)&ram[addr], 0x10000 - addr, 0);
// 		POKDEV(0x2, res);
// 		break;
// 	case 0xd:
// 		PEKDEV(addr, 0xc);
// 		PEKDEV(len, 0xa);
// 		if(len > 0x10000 - addr)
// 			len = 0x10000 - addr;
// 		res = file_read(c, &ram[addr], len);
// 		POKDEV(0x2, res);
// 		break;
// 	case 0xf:
// 		PEKDEV(addr, 0xe);
// 		PEKDEV(len, 0xa);
// 		if(len > 0x10000 - addr)
// 			len = 0x10000 - addr;
// 		res = file_write(c, &ram[addr], len, d[0x7]);
// 		POKDEV(0x2, res);
// 		break;
// 	}
// }
pub fn file_deo(id: u8, ram: []u8, d: [*]u8, port: u8) void {
    const c = &uxn_file[id];
    var addr: u16 = undefined;
    var len: u16 = undefined;
    var res: u16 = undefined;
    switch (port) {
        0x5 => {
            PEKDEV(&addr, 0x4, d);
            PEKDEV(&len, 0x4, d);
            const max_len = @intCast(u16, 0x10000 - @intCast(u17, addr));
            if (len > max_len)
                len = max_len;
            res = if (file_stat(c, ram[addr .. addr + len])) |n| n else |_| 0;
            POKDEV(0x2, res, d);
        },
        0x6 => {
            res = if (file_delete(c)) 1 else |_| 0;
            POKDEV(0x2, res, d);
        },
        0x9 => {
            PEKDEV(&addr, 0x8, d);
            res = if (file_init(c, ram[addr..0x10000], false)) 1 else |_| 0;
            POKDEV(0x2, res, d);
        },
        0xd => {
            PEKDEV(&addr, 0xc, d);
            PEKDEV(&len, 0xa, d);
            const max_len = @intCast(u16, 0x10000 - @intCast(u17, addr));
            if (len > max_len)
                len = max_len;
            res = if (file_read(c, ram[addr .. addr + len], len)) |n| n else |_| 0;
            POKDEV(0x2, res, d);
        },
        0xf => {
            PEKDEV(&addr, 0xe, d);
            PEKDEV(&len, 0xa, d);
            const max_len = @intCast(u16, 0x10000 - @intCast(u17, addr));
            if (len > max_len)
                len = max_len;
            res = if (file_write(c, ram[addr .. addr + len], d[0x7])) 1 else |_| 0;
            POKDEV(0x2, res, d);
        },
        // TODO: revisit
        else => {},
    }
}

// Uint8
// file_dei(Uint8 id, Uint8 *d, Uint8 port)
// {
// 	UxnFile *c = &uxn_file[id];
// 	Uint16 res;
// 	switch(port) {
// 	case 0xc:
// 	case 0xd:
// 		res = file_read(c, &d[port], 1);
// 		POKDEV(0x2, res);
// 		break;
// 	}
// 	return d[port];
// }
pub fn file_dei(id: u8, d: [*]u8, port: u8) !u8 {
    const c = &uxn_file[id];
    switch (port) {
        0xc, 0xd => {
            const res = try file_read(c, d[port .. port + 2], 1);
            POKDEV(0x2, res, d);
        },
        // TODO: revisit
        else => {},
    }
    return d[port];
}

// ** Boot **

// int
// load_rom(Uxn *u, char *filename)
// {
// 	int ret;
// 	file_init(uxn_file, filename, strlen(filename) + 1, 1);
// 	ret = file_read(uxn_file, &u->ram[PAGE_PROGRAM], 0x10000 - PAGE_PROGRAM);
// 	reset(uxn_file);
// 	return ret;
// }
pub fn load_rom(u: *Uxn, filename: []const u8) !u16 {
    try file_init(&uxn_file[0], filename, true);
    const ret = try file_read(&uxn_file[0], u.ram[PAGE_PROGRAM..0x10000], 0x10000 - PAGE_PROGRAM);
    reset(&uxn_file[0]);
    return ret;
}
