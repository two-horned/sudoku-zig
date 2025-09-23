const std = @import("std");
const lib = @import("sudoku_lib");

pub fn main() !void {
    var stdout_buf: [256]u8 = undefined;
    var stderr_buf: [256]u8 = undefined;
    var stdin_buf: [82]u8 = undefined;

    var stdout_writer = std.fs.File.stdout().writer(&stdout_buf);
    var stderr_writer = std.fs.File.stderr().writer(&stderr_buf);
    var stdin_reader = std.fs.File.stdin().reader(&stdin_buf);

    const stdout = &stdout_writer.interface;
    const stderr = &stderr_writer.interface;
    const stdin = &stdin_reader.interface;

    try stdout.print("Enter each sudoku puzzle as one line. Press Ctr-D to quit.\n", .{});
    try stdout.flush();

    var game = lib.Game{};
    var timer = try std.time.Timer.start();
    var mini_timer = try std.time.Timer.start();
    outer_loop: while (true) : (game.clear()) if (stdin.takeDelimiterInclusive('\n')) |msg| {
        mini_timer.reset();
        for (0..81) |i| switch (msg[i]) {
            '.' => {},
            '1'...'9' => |v| game.choose(i, v - '1'),
            '\n' => {
                try stderr.print("Input too short\n", .{});
                try stderr.flush();
                continue :outer_loop;
            },
            else => |c| {
                try stderr.print("Illegal character '{c}'\n", .{c});
                try stderr.flush();
                continue :outer_loop;
            },
        };
        try stdout.print("Input:       {s}\n", .{msg});
        if (lib.eval(&game)) {
            for (0..81) |i| game.board[i] += '1';
            try stdout.print("Solution:    {s}\n", .{game.board});
        } else |_| {
            try stdout.print("Game cannot be solved.\n", .{});
        }
        const read = mini_timer.read() / std.time.ns_per_us;
        try stdout.print("Time needed: {}µs.\n\n", .{read});
        try stdout.flush();
    } else |err| switch (err) {
        error.EndOfStream => break,
        error.StreamTooLong => {
            try stderr.print("Input too long\n", .{});
            try stderr.flush();
            _ = try stdin.discardDelimiterInclusive('\n');
        },
        else => |e| return e,
    };

    const read = timer.read() / std.time.ns_per_ms;
    try stdout.print("Total time needed: {}ms.\nBye\n", .{read});
    try stdout.flush();
}
