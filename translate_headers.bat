@echo off
zig translate-c -lc headers/raylib.h > src/gen/raylib.zig