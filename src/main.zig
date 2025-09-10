const std = @import("std");
const lib = @import("sudoku_lib");

pub fn main() !void {
    const stdout_file = std.io.getStdOut().writer();
    const stderr_file = std.io.getStdErr().writer();
    const stdin_file = std.io.getStdIn().reader();

    var stdout_bw = std.io.bufferedWriter(stdout_file);
    var stderr_bw = std.io.bufferedWriter(stderr_file);
    var stdin_br = std.io.bufferedReaderSize(81, stdin_file);

    const stdout = stdout_bw.writer();
    const stderr = stderr_bw.writer();
    const stdin = stdin_br.reader();

    var buf: [82]u8 = undefined;

    try stdout.print("Enter each sudoku puzzle as one line. Press Ctr-D to quit.\n", .{});
    try stdout_bw.flush();

    var timer = try std.time.Timer.start();
    var mini_timer = try std.time.Timer.start();
    outer_loop: while (true) {
        if (stdin.readUntilDelimiterOrEof(&buf, '\n')) |msg_or_null| {
            const msg = msg_or_null orelse break;

            try stdout.print("Input:       {s}\n", .{msg});
            try stdout_bw.flush();

            mini_timer.reset();
            var game = lib.Game{};
            inline for (0..81) |i| {
                switch (msg[i]) {
                    '.' => {},
                    '1'...'9' => |v| game.choose(i, v - '1'),
                    '\n' => {
                        try stderr.print("Input too short\n", .{});
                        try stderr_bw.flush();
                        continue :outer_loop;
                    },
                    else => |c| {
                        try stderr.print("Illegal character {c}\n", .{c});
                        try stderr_bw.flush();
                        continue :outer_loop;
                    },
                }
            }
            if (lib.eval(&game)) |_| {
                inline for (0..81) |i| {
                    game.board[i] += '1';
                }
                try stdout.print("Solution:    {s}\n", .{game.board});
            } else |_| {
                try stdout.print("Game cannot be solved.\n", .{});
            }
            const read = mini_timer.read() / std.time.ns_per_us;
            try stdout.print("Time needed: {}µs.\n\n", .{read});
            try stdout_bw.flush();
        } else |err| switch (err) {
            error.StreamTooLong => {
                try stderr.print("Input too long\n", .{});
                try stderr_bw.flush();
                try stdin.skipUntilDelimiterOrEof('\n');
            },
            else => |e| return e,
        }
    }

    const read = timer.read() / std.time.ns_per_ms;
    try stdout.print("Total time needed: {}ms.\nBye\n", .{read});
    try stdout_bw.flush();
}
