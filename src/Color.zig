const Color = @This();

r: u8,
g: u8,
b: u8,
a: u8,

pub const black = from888(0, 0, 0);
pub const light_grey = from888(0xa0, 0xa0, 0xa0);
pub const white = from888(0xff, 0xff, 0xff);

fn toByte(val: u5) u8 {
    return (@as(u8, val) << 3) | (val >> 2);
}

pub fn from16(c: u16) Color {
    return .{
        .r = toByte(@intCast(c & 0x1f)),
        .g = toByte(@intCast((c >> 5) & 0x1f)),
        .b = toByte(@intCast((c >> 10) & 0x1f)),
        .a = if ((c >> 15) > 0) 0xff else 0,
    };
}

pub fn from888(r: u8, g: u8, b: u8) Color {
    return from8888(r, g, b, 0xff);
}

pub fn from8888(r: u8, g: u8, b: u8, a: u8) Color {
    const qr = r >> 3;
    const qg = g >> 3;
    const qb = b >> 3;
    const qa = a >> 7;
    return .{
        .r = (qr << 3) | (qr >> 2),
        .g = (qg << 3) | (qg >> 2),
        .b = (qb << 3) | (qb >> 2),
        .a = if (qa > 0) 0xff else 0,
    };
}
