const std = @import("std");

/// This imports the separate module containing `root.zig`. Take a look in `build.zig` for details.
const lib = @import("sudoku_lib");

pub fn main() !void {
    var timer = try std.time.Timer.start();

    const stdout_file = std.io.getStdOut().writer();
    const stderr_file = std.io.getStdErr().writer();
    // const stdin_file = std.io.getStdIn().reader();

    var stdout_bw = std.io.bufferedWriter(stdout_file);
    var stderr_bw = std.io.bufferedWriter(stderr_file);
    // var stdin_br = std.io.bufferedReader(stdin_file);

    const stdout = stdout_bw.writer();
    const stderr = stderr_bw.writer();
    // const stdin = stdin_br.reader();

    var game = lib.Game{};
    try stdout.print("Hello, world, this my game {}.\n", .{game});
    try stdout_bw.flush(); // Don't forget to flush!
    var evaluater = lib.Evaluater{};

    game.choose(0, 0);
    try stdout.print("I have chosen...\n", .{});
    try stdout.print("Now this my game {}.\n", .{game});
    try stdout_bw.flush(); // Don't forget to flush!

    evaluater.eval(&game) catch try stderr.print("Game is unsolvable.\n", .{});
    try stderr_bw.flush();

    try stdout.print("Finally, this my game {}.\n", .{game});
    try stdout_bw.flush(); // Don't forget to flush!

    const read = timer.read();
    try stdout.print("Time elapsed is {}us.\n", .{read / std.time.ns_per_us});
    try stdout_bw.flush(); // Don't forget to flush!
}
