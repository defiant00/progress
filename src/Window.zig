const std = @import("std");
const Color = @import("Color.zig");
const Core = @import("Core.zig");
const sdl = @cImport({
    @cInclude("SDL.h");
});

const graphics_file = @embedFile("graphics.g16");

const RENDER_WIDTH = 512;
const RENDER_HEIGHT = 256;

const GRAPHICS_WIDTH = 512;
const GRAPHICS_HEIGHT = 512;

// game updates four times a second
const UPDATE_MS = 250;

const Window = @This();

window: ?*sdl.SDL_Window,
renderer: ?*sdl.SDL_Renderer,
framebuffer: ?*sdl.SDL_Texture,
graphics_buffer: ?*sdl.SDL_Texture,
tick: u64,
fullscreen: bool,
pixel_perfect: bool,
screen_rect: sdl.SDL_Rect,
screen_scale: f32,

pub fn init() !Window {
    // graphics
    var gr_buf = std.io.fixedBufferStream(graphics_file);
    var dec = std.compress.flate.decompressor(gr_buf.reader());
    var dec_r = dec.reader();
    const w: usize = try dec_r.readInt(u16, .little);
    const h: usize = try dec_r.readInt(u16, .little);

    const gr_surf = sdl.SDL_CreateRGBSurface(
        0,
        GRAPHICS_WIDTH,
        GRAPHICS_HEIGHT,
        32,
        0xff,
        0xff00,
        0xff0000,
        0xff000000,
    ) orelse {
        sdl.SDL_Log("Unable to create surface: %s", sdl.SDL_GetError());
        return error.SDLInitializationFailed;
    };

    if (sdl.SDL_LockSurface(gr_surf) != 0) {
        sdl.SDL_Log("Unable to lock surface: %s", sdl.SDL_GetError());
        return error.SDLInitializationFailed;
    }
    const pixels: [*]u32 = @ptrCast(@alignCast(gr_surf.*.pixels));
    for (0..h) |hi| {
        for (0..w) |wi| {
            const uc = try dec_r.readInt(u16, .little);
            const color = Color.from16(uc);
            pixels[hi * GRAPHICS_WIDTH + wi] = sdl.SDL_MapRGBA(
                gr_surf.*.format,
                color.r,
                color.g,
                color.b,
                color.a,
            );
        }
    }
    sdl.SDL_UnlockSurface(gr_surf);

    // SDL
    if (sdl.SDL_Init(sdl.SDL_INIT_VIDEO) != 0) {
        sdl.SDL_Log("Unable to init SDL: %s", sdl.SDL_GetError());
        return error.SDLInitializationFailed;
    }

    const window = sdl.SDL_CreateWindow(
        "Progress",
        sdl.SDL_WINDOWPOS_CENTERED,
        sdl.SDL_WINDOWPOS_CENTERED,
        RENDER_WIDTH,
        RENDER_HEIGHT,
        sdl.SDL_WINDOW_RESIZABLE,
    ) orelse {
        sdl.SDL_Log("Unable to create window: %s", sdl.SDL_GetError());
        return error.SDLInitializationFailed;
    };

    const renderer = sdl.SDL_CreateRenderer(window, -1, sdl.SDL_RENDERER_PRESENTVSYNC) orelse {
        sdl.SDL_Log("Unable to create renderer: %s", sdl.SDL_GetError());
        return error.SDLInitializationFailed;
    };

    const framebuffer = sdl.SDL_CreateTexture(
        renderer,
        sdl.SDL_PIXELFORMAT_ARGB8888,
        sdl.SDL_TEXTUREACCESS_TARGET,
        RENDER_WIDTH,
        RENDER_HEIGHT,
    ) orelse {
        sdl.SDL_Log("Unable to create texture: %s", sdl.SDL_GetError());
        return error.SDLInitializationFailed;
    };

    const graphics_buffer = sdl.SDL_CreateTextureFromSurface(renderer, gr_surf) orelse {
        sdl.SDL_Log("Unable to create vram: %s", sdl.SDL_GetError());
        return error.SDLInitializationFailed;
    };

    sdl.SDL_FreeSurface(gr_surf);

    return .{
        .window = window,
        .renderer = renderer,
        .framebuffer = framebuffer,
        .graphics_buffer = graphics_buffer,
        .tick = getTick(),
        .fullscreen = false,
        .pixel_perfect = false,
        .screen_rect = sdl.SDL_Rect{
            .x = 0,
            .y = 0,
            .w = RENDER_WIDTH,
            .h = RENDER_HEIGHT,
        },
        .screen_scale = 1,
    };
}

pub fn deinit(self: Window) void {
    if (self.graphics_buffer) |graphics_buffer| sdl.SDL_DestroyTexture(graphics_buffer);
    if (self.framebuffer) |framebuffer| sdl.SDL_DestroyTexture(framebuffer);
    if (self.renderer) |renderer| sdl.SDL_DestroyRenderer(renderer);
    if (self.window) |window| sdl.SDL_DestroyWindow(window);
    sdl.SDL_Quit();
}

pub fn run(self: *Window) !void {
    var game = Core.init();
    defer game.deinit();

    var running = true;
    var event: sdl.SDL_Event = undefined;

    while (running) {
        while (sdl.SDL_PollEvent(&event) != 0) {
            switch (event.type) {
                sdl.SDL_KEYDOWN => {
                    if (event.key.keysym.mod & sdl.KMOD_ALT > 0) {
                        switch (event.key.keysym.sym) {
                            sdl.SDLK_RETURN => try self.toggleFullscreen(),
                            sdl.SDLK_p => self.togglePixelPerfect(),
                            else => {},
                        }
                    }
                },
                sdl.SDL_WINDOWEVENT => {
                    if (event.window.event == sdl.SDL_WINDOWEVENT_SIZE_CHANGED) {
                        const x = event.window.data1;
                        const y = event.window.data2;
                        self.resize(x, y);
                    }
                },
                sdl.SDL_QUIT => running = false,
                else => {},
            }
        }

        // update
        const tick = getTick();
        if (tick > self.tick) {
            self.tick = tick;
            game.tick();
        }

        // set render target to framebuffer
        if (sdl.SDL_SetRenderTarget(self.renderer, self.framebuffer) != 0) {
            sdl.SDL_Log("Unable to set render target to framebuffer: %s", sdl.SDL_GetError());
            return error.SDLError;
        }

        // clear framebuffer
        try self.setColor(Color.black);
        if (sdl.SDL_RenderClear(self.renderer) != 0) {
            sdl.SDL_Log("Unable to clear framebuffer: %s", sdl.SDL_GetError());
            return error.SDLError;
        }

        // draw
        try self.tint(Color.white);
        try self.print(4, 4, "Progress!", .{});
        try self.tint(Color.light_grey);
        try self.print(4, 16, "Kibble: {}", .{game.state.kibble});

        // set render target to window
        if (sdl.SDL_SetRenderTarget(self.renderer, null) != 0) {
            sdl.SDL_Log("Unable to set render target to window: %s", sdl.SDL_GetError());
            return error.SDLError;
        }

        // clear window
        try self.setColor(Color.black);
        if (sdl.SDL_RenderClear(self.renderer) != 0) {
            sdl.SDL_Log("Unable to clear render: %s", sdl.SDL_GetError());
            return error.SDLError;
        }

        // render framebuffer
        if (sdl.SDL_RenderCopy(self.renderer, self.framebuffer, &sdl.SDL_Rect{
            .x = 0,
            .y = 0,
            .w = RENDER_WIDTH,
            .h = RENDER_HEIGHT,
        }, &self.screen_rect) != 0) {
            sdl.SDL_Log("Unable to render framebuffer: %s", sdl.SDL_GetError());
            return error.SDLError;
        }

        sdl.SDL_RenderPresent(self.renderer);
    }
}

fn getTick() u64 {
    return sdl.SDL_GetTicks64() / UPDATE_MS;
}

fn print(self: Window, x: u16, y: u16, comptime fmt: []const u8, args: anytype) !void {
    var buf: [128]u8 = undefined;
    const text = try std.fmt.bufPrint(&buf, fmt, args);

    var src = sdl.SDL_Rect{ .x = 0, .y = 0, .w = 3, .h = 7 };
    var dest = sdl.SDL_Rect{ .x = x, .y = y, .w = 3, .h = 7 };
    {
        var i: usize = 0;
        while (i < text.len) : (i += 1) {
            const c = text[i];
            switch (c) {
                ' ' => dest.x += 4,
                '\t' => dest.x += 8,
                '\r' => dest.x = x,
                '\n' => {
                    dest.x = x;
                    dest.y += 8;
                },
                else => {
                    src.w = 3;
                    if (c > ' ' and c < 127) {
                        src.x = (@as(c_int, c) - ' ') * 4;

                        if (c == '!' or c == '\'' or c == '.' or c == ':' or c == 'i' or c == '|') {
                            src.x += 1;
                            src.w = 1;
                        } else if (c == ',' or c == ';' or c == '`') {
                            src.w = 2;
                        } else if (c == 'l') {
                            src.x += 1;
                            src.w = 2;
                        }
                    } else {
                        src.x = 0;
                    }
                    dest.w = src.w;

                    if (sdl.SDL_RenderCopy(self.renderer, self.graphics_buffer, &src, &dest) != 0) {
                        sdl.SDL_Log("Unable to render text: %s", sdl.SDL_GetError());
                        return error.SDLError;
                    }
                    dest.x += dest.w + 1;
                },
            }
        }
    }
}

fn printMono(self: Window, x: u16, y: u16, comptime fmt: []const u8, args: anytype) !void {
    var buf: [128]u8 = undefined;
    const text = try std.fmt.bufPrint(&buf, fmt, args);

    var src = sdl.SDL_Rect{ .x = 0, .y = 0, .w = 3, .h = 7 };
    var dest = sdl.SDL_Rect{ .x = x, .y = y, .w = 3, .h = 7 };
    {
        var i: usize = 0;
        while (i < text.len) : (i += 1) {
            const c = text[i];
            switch (c) {
                ' ' => dest.x += 4,
                '\t' => dest.x += 8,
                '\r' => dest.x = x,
                '\n' => {
                    dest.x = x;
                    dest.y += 8;
                },
                else => {
                    if (c > ' ' and c < 127) {
                        src.x = (@as(c_int, c) - ' ') * 4;
                    } else {
                        src.x = 0;
                    }

                    if (sdl.SDL_RenderCopy(self.renderer, self.graphics_buffer, &src, &dest) != 0) {
                        sdl.SDL_Log("Unable to render text: %s", sdl.SDL_GetError());
                        return error.SDLError;
                    }
                    dest.x += 4;
                },
            }
        }
    }
}

fn resize(self: *Window, x: i32, y: i32) void {
    const fx: f32 = @floatFromInt(x);
    const fy: f32 = @floatFromInt(y);
    self.screen_scale = @min(fx / RENDER_WIDTH, fy / RENDER_HEIGHT);
    if (self.pixel_perfect and self.screen_scale > 1) {
        self.screen_scale = @floor(self.screen_scale);
    }

    self.screen_rect.x = @intFromFloat((fx - (self.screen_scale * RENDER_WIDTH)) / 2);
    self.screen_rect.y = @intFromFloat((fy - (self.screen_scale * RENDER_HEIGHT)) / 2);

    self.screen_rect.w = @intFromFloat(self.screen_scale * RENDER_WIDTH);
    self.screen_rect.h = @intFromFloat(self.screen_scale * RENDER_HEIGHT);
}

fn setColor(self: Window, c: Color) !void {
    if (sdl.SDL_SetRenderDrawColor(self.renderer, c.r, c.g, c.b, c.a) != 0) {
        sdl.SDL_Log("Unable to set color: %s", sdl.SDL_GetError());
        return error.SDLError;
    }
}

fn tint(self: Window, c: Color) !void {
    if (sdl.SDL_SetTextureColorMod(self.graphics_buffer, c.r, c.g, c.b) != 0) {
        sdl.SDL_Log("Unable to set tint color: %s", sdl.SDL_GetError());
        return error.SDLError;
    }
}

fn toggleFullscreen(self: *Window) !void {
    self.fullscreen = !self.fullscreen;
    if (sdl.SDL_SetWindowFullscreen(
        self.window,
        if (self.fullscreen) sdl.SDL_WINDOW_FULLSCREEN_DESKTOP else 0,
    ) != 0) {
        sdl.SDL_Log("Unable to toggle fullscreen: %s", sdl.SDL_GetError());
        return error.SDLError;
    }
}

fn togglePixelPerfect(self: *Window) void {
    self.pixel_perfect = !self.pixel_perfect;

    var x: c_int = 0;
    var y: c_int = 0;
    sdl.SDL_GetWindowSize(self.window, &x, &y);
    self.resize(x, y);
}
