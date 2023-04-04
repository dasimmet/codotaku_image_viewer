pub const Picture = @This();
const raylib = @import("gen/raylib.zig");
const std = @import("std");
const scale_duration = 1000000000000000000;
const scale_delta = 0.002;
const rot_duration = 0.1;
const rot_delta = 0.02;

texture: raylib.Texture2D,
pos: raylib.Vector2 = std.mem.zeroes(raylib.Vector2),
size: raylib.Vector2 = std.mem.zeroes(raylib.Vector2),
scale: f32 = 1,
scale_target: f32 = 1,
z: f32 = 1,
rotation: f32 = 0,
rotation_target: f32 = 0,

pub inline fn texSize(self: Picture) raylib.Vector2 {
    return .{
        .x = @intToFloat(f32, self.texture.width),
        .y = @intToFloat(f32, self.texture.height),
    };
}

pub fn collides(self: Picture, vec: raylib.Vector2) bool {
    const rect = self.toRect();
    const in_x = vec.x > rect.x and vec.x < rect.x + rect.width;
    const in_y = vec.y > rect.y and vec.y < rect.x + rect.height;
    // std.debug.print("{any},{any},scale:{any},target:{any}\n", .{ in_x, in_y, self.scale, self.scale_target });
    return in_x and in_y;
}

pub fn rescale(self: *Picture, s: f32) void {
    const ts = texSize(self.*);
    self.scale_target = s;
    self.size.x = ts.x * self.scale;
    self.size.y = ts.y * self.scale;
    std.debug.print("scale:{any},target:{any}\n", .{ self.scale, self.scale_target });
}

pub fn draw(self: Picture) void {
    const sz = self.texSize();
    const src = raylib.struct_Rectangle{
        .x = 0,
        .y = 0,
        .height = sz.x,
        .width = sz.y,
    };

    var rect = self.toRect();
    const origin = raylib.Vector2{
        .x = rect.width / 2,
        .y = rect.height / 2,
    };
    rect.x += rect.width / 2;
    rect.y += rect.height / 2;

    if (@rem(raylib.GetTime(), 1) <= 0.1) {
        // std.debug.print("{any}\n", .{src});
        // std.debug.print("{any}\n", .{rect});
        // std.debug.print("{any}\n", .{sz});
        // std.debug.print("{any} {any}\n", .{ self.rotation, self.scale });
    }
    raylib.DrawTexturePro(self.texture, src, rect, origin, self.rotation, raylib.WHITE);
}

pub fn drag(self: *Picture, mouse: raylib.Vector2) void {
    self.pos.x += mouse.x;
    self.pos.y += mouse.y;
}

pub fn move(self: *Picture, time: f32) void {
    self.rescale(self.scale_target);
    if (std.math.fabs(self.scale - self.scale_target) < scale_delta) {
        self.scale = self.scale_target;
    } else {
        self.scale = self.scale_target * std.math.pow(f32, self.scale_target / self.scale, time / scale_duration);
    }

    self.rotation = raylib.Lerp(self.rotation, self.rotation_target, time / rot_duration);
}

pub fn toRect(self: Picture) raylib.struct_Rectangle {
    return .{
        .x = self.pos.x - self.size.x / 2,
        .y = self.pos.y - self.size.x / 2,
        .width = self.size.x,
        .height = self.size.x,
    };
}

pub const SortPicArgs = struct {
    reverse: bool = false,
};

pub fn sortPic(args: SortPicArgs, lhs: Picture, rhs: Picture) bool {
    if (args.reverse) {
        return lhs.z > rhs.z;
    } else {
        return lhs.z < rhs.z;
    }
}
