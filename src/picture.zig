pub const Picture = @This();
const raylib = @import("gen/raylib.zig");
const std = @import("std");
const scale_delta = 0.01;
const rot_delta = 0.8;

texture: raylib.Texture2D,
pos: raylib.Vector2 = std.mem.zeroes(raylib.Vector2),
size: raylib.Vector2 = std.mem.zeroes(raylib.Vector2),
vel: raylib.Vector2 = std.mem.zeroes(raylib.Vector2),
scale: f32 = 1,
scale_target: f32 = 1,
scale_vel: f32 = 0,
z: f32 = 1,
rot: f32 = 0,
rot_target: f32 = 0,
rot_vel: f32 = 0,

pub fn init(allocator: std.mem.Allocator, texture: raylib.Texture2D) !*Picture {
    var pic = (try allocator.create(Picture));
    pic.* = .{
        .texture = texture,
        .size = .{
            .x = @intToFloat(f32, texture.width),
            .y = @intToFloat(f32, texture.height),
        },
        .rot = 0,
        .rot_target = 0,
    };
    return pic;
}

pub fn deinit(self: *Picture, allocator: std.mem.Allocator) void {
    raylib.UnloadTexture(self.texture);
    allocator.destroy(self);
}

pub inline fn texSize(self: Picture) raylib.Vector2 {
    return .{
        .x = @intToFloat(f32, self.texture.width),
        .y = @intToFloat(f32, self.texture.height),
    };
}

pub fn collides(self: Picture, vec: raylib.Vector2) bool {
    const c = self.center();
    // raylib.Vector2Rotate(arg_v: Vector2, arg_angle: f32)
    _ = c;
    const rect = self.toRect();
    return raylib.CheckCollisionPointRec(vec, rect);
}

pub fn rescale(self: *Picture, s: f32) void {
    // const scale_lerp = raylib.Lerp(self.scale_target, s, self.scale);
    // self.scale_target = std.math.max(scale_lerp, scale_delta);
    self.scale_target = s;
}

pub fn setScale(self: *Picture, s: f32) void {
    self.scale = s;
    const ts = self.texSize();
    self.size.x = ts.x * self.scale;
    self.size.y = ts.y * self.scale;
}

pub fn draw(self: Picture, counter: u64) void {
    _ = counter;
    std.debug.print("z:{d},scale:{d},target:{d},vel:{d}\n", .{ self.z, self.scale, self.scale_target, self.scale_vel });
    std.debug.print("z:{d},rotation:{d},target:{any},vel:{any}\n", .{ self.z, self.rot, self.rot_target, self.rot_vel });

    inline for (.{ self.scale, self.rot, self.rot_vel, self.scale_vel }, 0..) |v, i| {
        if (v >= std.math.floatMax(f32) or v <= -1 * std.math.floatMax(f32)) {
            std.debug.print("max:{d},{d}\n", .{ std.math.floatMax(f32), v });
            @panic(std.fmt.comptimePrint("OVERFLOW: {d}\n", .{i}));
        }
    }
    // if (counter >= 10) @panic("");

    const sz = self.texSize();
    const src = raylib.Rectangle{
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
    raylib.DrawRectangleRec(rect, raylib.GREEN);
    rect.x += rect.width / 2;
    rect.y += rect.height / 2;

    raylib.DrawRectangleRec(rect, raylib.YELLOW);
    raylib.DrawTexturePro(self.texture, src, rect, origin, self.rot, raylib.WHITE);
    raylib.DrawCircleV(self.pos, 10, raylib.BLACK);
    raylib.DrawCircleV(self.center(), 10, raylib.BLACK);
    // raylib.DrawCircleV(raylib.Vector2Subtract(.{ .x = rect.x, .y = rect.y }, origin), 10, raylib.PURPLE);
}

pub fn center(self: Picture) raylib.Vector2 {
    return raylib.Vector2Add(self.pos, raylib.Vector2Scale(self.size, 0.5));
}

pub fn drag(self: *Picture, mouse: raylib.Vector2) void {
    self.pos = raylib.Vector2Add(self.pos, mouse);
}

pub fn move(self: *Picture, time: f32, move_center: raylib.Vector2) void {
    _ = move_center;
    const t = std.math.max(0.01, time);

    self.scale_vel = std.math.fabs(10 * (self.scale_target - self.scale) / self.scale);
    if (self.scale_vel < scale_delta) {
        std.debug.print("WOLOLO", .{});
        self.scale = self.scale_target;
    } else {
        self.setScale(raylib.Lerp(self.scale, self.scale_target, self.scale_vel * t));
        // _ = std.math.pow(f32, self.scale_vel, t);
        // self.scale = std.math.max(self.scale, 0.01);
    }

    self.rot_vel = std.math.fabs(self.rot_target - self.rot);

    if (self.rot_vel < rot_delta) {
        self.rot = self.rot_target;
    } else {
        self.rot = raylib.Lerp(self.rot, self.rot_target, self.rot_vel * t);
    }
}

pub fn toRect(self: Picture) raylib.struct_Rectangle {
    return .{
        .x = self.pos.x,
        .y = self.pos.y,
        .width = self.size.x,
        .height = self.size.y,
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
