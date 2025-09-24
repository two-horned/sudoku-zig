const std = @import("std");
const lib = @import("sudoku_lib");

pub fn main() !void {
    var stdout_buf: [256]u8 = undefined;
    var stderr_buf: [256]u8 = undefined;
    var stdin_buf: [82]u8 = undefined;

    var stdout_writer = std.fs.File.stdout().writer(&stdout_buf);
    var stderr_writer = std.fs.File.stderr().writer(&stderr_buf);
    var stdin_reader = std.fs.File.stdin().reader(&stdin_buf);

    _ = try stdout_writer.interface.write("Enter each sudoku puzzle as one line. Press Ctr-D to quit.\n");
    try stdout_writer.interface.flush();

    var game = lib.Game{};
    var timer = try std.time.Timer.start();
    var mini_timer = try std.time.Timer.start();
    outer_loop: while (true) : (game = lib.Game{}) if (stdin_reader.interface.takeDelimiterInclusive('\n')) |msg| {
        mini_timer.reset();
        for (0..81) |i| switch (msg[i]) {
            '.' => {},
            '1'...'9' => |v| game.choose(i, v - '1'),
            '\n' => {
                _ = try stderr_writer.interface.write("Input too short\n");
                try stderr_writer.interface.flush();
                continue :outer_loop;
            },
            else => |c| {
                try stderr_writer.interface.print("Illegal character '{c}'\n", .{c});
                try stderr_writer.interface.flush();
                continue :outer_loop;
            },
        };

        try stdout_writer.interface.print("Input:       {s}\n", .{msg});

        if (lib.eval(&game)) {
            for (0..81) |i| game.board[i] += '1';
            try stdout_writer.interface.print("Solution:    {s}\n", .{game.board});
        } else |_| try stdout_writer.interface.print("Game cannot be solved.\n", .{});

        const read = mini_timer.read() / std.time.ns_per_us;
        try stdout_writer.interface.print("Time needed: {}µs.\n\n", .{read});
        try stdout_writer.interface.flush();
    } else |err| switch (err) {
        else => |e| return e,
        error.EndOfStream => break,
        error.StreamTooLong => {
            _ = try stderr_writer.interface.write("Input too long\n");
            try stderr_writer.interface.flush();
            _ = try stdin_reader.interface.discardDelimiterInclusive('\n');
        },
    };

    const read = timer.read() / std.time.ns_per_ms;
    try stdout_writer.interface.print("Total time needed: {}ms.\nBye\n", .{read});
    try stdout_writer.interface.flush();
}
