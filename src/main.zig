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
const rotation_increment = 15;

fn focusCamera(camera: *raylib.Camera2D, screen_position: raylib.Vector2) void {
    camera.*.target = raylib.GetScreenToWorld2D(screen_position, camera.*);
    camera.*.offset = screen_position;
}

pub fn main() error{OutOfMemory}!void {
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

    while (!raylib.WindowShouldClose()) {
        if (raylib.IsKeyPressed(toggle_fullscreen_key)) {
            raylib.ToggleFullscreen();
        }

        if (raylib.IsKeyPressed(clear_textures_key)) {
            for (pictures.items) |pic| {
                raylib.UnloadTexture(pic.texture);
                allocator.destroy(&pic);
            }
            pictures.clearRetainingCapacity();
        }

        const mouse_wheel_move = raylib.GetMouseWheelMove();
        const mouse_position = raylib.GetMousePosition();

        if (mouse_wheel_move != 0) {
            std.sort.sort(Picture, pictures.items, Picture.SortPicArgs{ .reverse = true }, Picture.sortPic);
            if (raylib.IsKeyDown(raylib.KEY_LEFT_SHIFT)) {
                for (pictures.items) |*pic| {
                    if (pic.collides(mouse_position)) {
                        pic.rotation_target += mouse_wheel_move * rotation_increment;
                        break;
                    }
                }
            } else {
                for (pictures.items) |*pic| {
                    if (pic.collides(mouse_position)) {
                        pic.rescale(std.math.max(pic.scale_target + mouse_wheel_move * zoom_increment, zoom_increment));
                        break;
                    }
                }
            }
        }

        if (raylib.IsMouseButtonPressed(raylib.MOUSE_LEFT_BUTTON)) {
            if (raylib.IsKeyDown(raylib.KEY_LEFT_SHIFT)) {
                if (pictures.popOrNull()) |pic| {
                    raylib.UnloadTexture(pic.texture);
                    allocator.destroy(&pic);
                    pictures.clearRetainingCapacity();
                }
            }
        }
        if (raylib.IsMouseButtonDown(raylib.MOUSE_LEFT_BUTTON)) {
            std.sort.sort(Picture, pictures.items, Picture.SortPicArgs{ .reverse = true }, Picture.sortPic);
            for (pictures.items) |*pic| {
                if (pic.collides(mouse_position)) {
                    const mouse_delta = raylib.GetMouseDelta();
                    pic.pos.x = pic.pos.x + mouse_delta.x;
                    pic.pos.y = pic.pos.y + mouse_delta.y;
                    break;
                }
            }
            // const translation = raylib.Vector2Scale(raylib.GetMouseDelta(), -1 / target_zoom);
            // camera.target = raylib.Vector2Add(camera.target, raylib.Vector2Rotate(translation, -camera.rotation * raylib.DEG2RAD));
        }

        if (raylib.IsKeyPressed(cycle_filter_key)) {
            texture_filter = @mod(texture_filter + 1, 3);
            for (pictures.items) |pic| {
                raylib.SetTextureFilter(pic.texture, texture_filter);
            }
        }

        if (raylib.IsFileDropped()) {
            try dropFile(allocator, &pictures, texture_filter);
        }

        const frame_time = raylib.GetFrameTime();
        for (pictures.items) |*pic| {
            pic.move(frame_time);
        }

        draw(camera, pictures);
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

    var pic = (try allocator.create(Picture)).*;
    pic = .{
        .texture = texture,
        .pos = .{
            .x = screen.x / 2,
            .y = screen.y / 2,
        },
        .size = .{
            .x = @intToFloat(f32, texture.width),
            .y = @intToFloat(f32, texture.height),
        },
        .rotation = 0,
        .rotation_target = 0,
    };
    pic.rescale(std.math.min(screen.x / pic.size.x, screen.y / pic.size.y));

    try pictures.append(pic);
}

pub fn dropFile(allocator: std.mem.Allocator, pictures: *PictureArrayList, filter: c_int) error{OutOfMemory}!void {
    const dropped_files = raylib.LoadDroppedFiles();
    defer raylib.UnloadDroppedFiles(dropped_files);

    for (dropped_files.paths[0..dropped_files.count]) |dropped_file_path| {
        try loadFile(allocator, pictures, filter, dropped_file_path);
    }
}

pub fn draw(camera: raylib.Camera2D, pictures: PictureArrayList) void {
    raylib.BeginDrawing();
    defer raylib.EndDrawing();

    raylib.ClearBackground(raylib.BLUE);

    raylib.BeginMode2D(camera);
    defer raylib.EndMode2D();

    std.sort.sort(Picture, pictures.items, Picture.SortPicArgs{}, Picture.sortPic);
    for (pictures.items) |pic| {
        pic.draw();
    }
}
