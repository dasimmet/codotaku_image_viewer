const std = @import("std");
const raylib = @import("gen/raylib.zig");
const Picture = @import("picture.zig").Picture;

const PictureArrayList = std.ArrayList(Picture);

const title = "Codotaku Image Viewer";
const cycle_filter_key = raylib.KEY_P;
const clear_textures_key = raylib.KEY_BACKSPACE;
const toggle_fullscreen_key = raylib.KEY_F;
const zoom_increment = 0.1;
const vector2_zero = raylib.Vector2Zero();
const rotation_increment = 5;

pub fn main() error{OutOfMemory}!void {
    var frame_counter: u64 = 0;

    raylib.SetConfigFlags(raylib.FLAG_WINDOW_RESIZABLE | raylib.FLAG_VSYNC_HINT | raylib.FLAG_WINDOW_HIGHDPI);
    raylib.InitWindow(800, 600, title);
    defer raylib.CloseWindow();

    var arena = std.heap.ArenaAllocator.init(std.heap.c_allocator);
    defer arena.deinit();
    var allocator = arena.allocator();

    var pictures = PictureArrayList.init(allocator);

    var texture_filter = raylib.TEXTURE_FILTER_TRILINEAR;
    if (std.os.argv.len >= 2) {
        for (std.os.argv[1..]) |arg| {
            try loadFile(allocator, &pictures, texture_filter, arg);
        }
    }

    var camera = raylib.Camera2D{
        .offset = vector2_zero,
        .target = vector2_zero,
        .rotation = 0,
        .zoom = 1,
    };
    const frame_time = raylib.GetFrameTime();

    while (!raylib.WindowShouldClose()) {
        var dragging: bool = false;
        var rotating: bool = false;
        var scaling: bool = false;
        if (raylib.IsKeyPressed(toggle_fullscreen_key)) {
            raylib.ToggleFullscreen();
        }
        const mouse_wheel_move = raylib.GetMouseWheelMove();
        const mouse_position = raylib.GetMousePosition();

        std.sort.sort(Picture, pictures.items, Picture.SortPicArgs{ .reverse = true }, Picture.sortPic);
        for (pictures.items) |*pic| {
            const collides_mouse = pic.collides(mouse_position);
            if (raylib.IsKeyPressed(clear_textures_key)) {
                pic.deinit(allocator);
                pictures.clearRetainingCapacity();
                continue;
            }
            if (mouse_wheel_move != 0) {
                if (raylib.IsKeyDown(raylib.KEY_LEFT_SHIFT)) {
                    if ((!rotating) and collides_mouse) {
                        pic.rot_target += mouse_wheel_move * rotation_increment;
                        rotating = true;
                    }
                } else if ((!scaling) and collides_mouse) {
                    pic.rescale(pic.scale_target + mouse_wheel_move * zoom_increment);
                    scaling = true;
                }
            }
            if (raylib.IsMouseButtonDown(raylib.MOUSE_LEFT_BUTTON)) {
                if ((!dragging) and collides_mouse) {
                    const mouse_delta = raylib.GetMouseDelta();
                    pic.drag(mouse_delta);
                    dragging = true;
                }
            }
            if (raylib.IsKeyPressed(cycle_filter_key)) {
                texture_filter = @mod(texture_filter + 1, 3);
                raylib.SetTextureFilter(pic.texture, texture_filter);
            }
            pic.move(frame_time, mouse_position);
        }

        if (raylib.IsFileDropped()) {
            try dropFile(allocator, &pictures, texture_filter);
        }

        draw(camera, pictures, frame_counter);
        frame_counter += 1;
    }
}

pub fn loadFile(allocator: std.mem.Allocator, pictures: *PictureArrayList, filter: c_int, file_path: [*c]const u8) error{OutOfMemory}!void {
    var texture = raylib.LoadTexture(file_path);
    if (texture.id == 0) return;
    raylib.GenTextureMipmaps(&texture);
    if (texture.mipmaps == 1) {
        std.debug.print("{s}", .{"Mipmaps failed to generate!\n"});
    }
    raylib.SetTextureFilter(texture, filter);

    const screen = raylib.Vector2{
        .x = @intToFloat(f32, raylib.GetScreenWidth()),
        .y = @intToFloat(f32, raylib.GetScreenHeight()),
    };

    var pic = (try Picture.init(allocator, texture)).*;

    pic.z = @intToFloat(f32, pictures.items.len);

    pic.setScale(std.math.min(screen.x / pic.size.x, screen.y / pic.size.y));
    pic.rescale(pic.scale);
    const scaled_size = pic.toRect();
    // std.debug.print("{any}\n{any}\n", .{ scaled_size, screen });
    pic.pos.x = 0.5 * (screen.x - scaled_size.width);
    pic.pos.y = 0.5 * (screen.y - scaled_size.height);
    // std.debug.print("{any}\n{any}\n", .{ pic.toRect(), screen });
    // false or @panic("");

    try pictures.append(pic);
}

pub fn dropFile(allocator: std.mem.Allocator, pictures: *PictureArrayList, filter: c_int) error{OutOfMemory}!void {
    const dropped_files = raylib.LoadDroppedFiles();
    defer raylib.UnloadDroppedFiles(dropped_files);

    for (dropped_files.paths[0..dropped_files.count]) |dropped_file_path| {
        try loadFile(allocator, pictures, filter, dropped_file_path);
    }
}

pub fn draw(camera: raylib.Camera2D, pictures: PictureArrayList, counter: u64) void {
    raylib.BeginDrawing();
    defer raylib.EndDrawing();

    raylib.ClearBackground(raylib.BLUE);

    raylib.BeginMode2D(camera);
    defer raylib.EndMode2D();

    std.sort.sort(Picture, pictures.items, Picture.SortPicArgs{}, Picture.sortPic);
    for (pictures.items) |pic| {
        pic.draw(counter);
    }
    // raylib.DrawText("WOLOLO", 0, 0, 100, raylib.BLACK);
}
