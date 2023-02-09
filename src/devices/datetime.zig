// Uint8
// datetime_dei(Uint8 *d, Uint8 port)
// {
// 	time_t seconds = time(NULL);
// 	struct tm zt = {0};
// 	struct tm *t = localtime(&seconds);
// 	if(t == NULL)
// 		t = &zt;
// 	switch(port) {
// 	case 0x0: return (t->tm_year + 1900) >> 8;
// 	case 0x1: return (t->tm_year + 1900);
// 	case 0x2: return t->tm_mon;
// 	case 0x3: return t->tm_mday;
// 	case 0x4: return t->tm_hour;
// 	case 0x5: return t->tm_min;
// 	case 0x6: return t->tm_sec;
// 	case 0x7: return t->tm_wday;
// 	case 0x8: return t->tm_yday >> 8;
// 	case 0x9: return t->tm_yday;
// 	case 0xa: return t->tm_isdst;
// 	default: return d[port];
// 	}
// }
pub fn datetime_dei(d: [*]u8, port: u8) u8 {
    // TODO:
    _ = d;
    _ = port;
    return 1;
}
