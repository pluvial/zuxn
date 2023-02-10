const std = @import("std");
const uxn = @import("../uxn.zig");

const PAGE_PROGRAM = uxn.PAGE_PROGRAM;
const POKDEV = uxn.POKDEV;
const Uxn = uxn.Uxn;

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
    dir: ?std.fs.Dir,
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
fn file_read_dir(c: *UxnFile, dest: []u8, len: u16) u16 {
    // TODO;
    _ = c;
    _ = dest;
    _ = len;
    return 1;
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
fn retry_realpath(file_name: []const u8) []const u8 {
    // TODO
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
fn file_check_sandbox(c: *UxnFile) void {
    // TODO
    _ = c;
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
fn file_init(c: *UxnFile, filename: []const u8, override_sandbox: bool) void {
    reset(c);
    c.current_filename = c.buffer_filename[0..filename.len];
    std.mem.copy(u8, c.current_filename, filename);
    if (!override_sandbox)
        file_check_sandbox(c);
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
        std.debug.print("current_filename: {s}\n", .{c.current_filename});
        c.dir = std.fs.cwd().openDir(c.current_filename, .{}) catch null;
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
        return file_read_dir(c, dest, len);
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
// file_delete(UxnFile *c)
// {
// 	return c->outside_sandbox ? 0 : unlink(c->current_filename);
// }

// /* IO */

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
    _ = id;
    _ = ram;
    _ = d;
    _ = port;
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
        else => unreachable,
    }
    return d[port];
}

// /* Boot */

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
    file_init(&uxn_file[0], filename, true);
    const ret = try file_read(&uxn_file[0], u.ram[PAGE_PROGRAM..0x10000], 0x10000 - PAGE_PROGRAM);
    reset(&uxn_file[0]);
    return ret;
}
