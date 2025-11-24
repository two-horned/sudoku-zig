const std = @import("std");
const lib = @import("sudoku_lib");

pub fn main() !void {
    var stdout_buf: [256]u8 = undefined;
    var stderr_buf: [256]u8 = undefined;
    var stdin_buf: [82]u8 = undefined;

    var out_writer = std.fs.File.stdout().writer(&stdout_buf);
    var err_writer = std.fs.File.stderr().writer(&stderr_buf);
    var in_reader = std.fs.File.stdin().reader(&stdin_buf);

    _ = try out_writer
        .interface
        .write("Enter each sudoku puzzle as one line. Press Ctr-D to quit.\n");
    try out_writer.interface.flush();

    var timer = try std.time.Timer.start();
    var mini_timer = try std.time.Timer.start();
    outer_loop: while (true) {
        var game = lib.Game{};
        if (in_reader.interface.takeDelimiterInclusive('\n')) |msg| {
            mini_timer.reset();
            for (0..81) |i| switch (msg[i]) {
                '.' => {},
                '1'...'9' => |v| game.choose(i, v - '1'),
                '\n' => {
                    _ = try err_writer.interface.write("Input too short\n");
                    try err_writer.interface.flush();
                    continue :outer_loop;
                },
                else => |c| {
                    try err_writer
                        .interface
                        .print("Illegal character '{c}'\n", .{c});
                    try err_writer.interface.flush();
                    continue :outer_loop;
                },
            };

            try out_writer.interface.print("Input:       {s}\n", .{msg});

            if (lib.eval(&game)) {
                for (0..81) |i| game.board[i] += '1';
                try out_writer
                    .interface
                    .print("Solution:    {s}\n", .{game.board});
            } else |_| try out_writer
                .interface
                .print("Game cannot be solved.\n", .{});

            const now = mini_timer.read() / std.time.ns_per_us;
            try out_writer
                .interface
                .print("Time needed: {}µs.\n\n", .{now});
            try out_writer.interface.flush();
        } else |err| switch (err) {
            else => return err,
            error.EndOfStream => break,
            error.StreamTooLong => {
                _ = try err_writer.interface.write("Input too long\n");
                try err_writer.interface.flush();
                _ = try in_reader.interface.discardDelimiterInclusive('\n');
            },
        }
    }

    const now = timer.read() / std.time.ns_per_ms;
    try out_writer
        .interface
        .print("Total time needed: {}ms.\nBye\n", .{now});
    try out_writer.interface.flush();
}
