const std = @import("std");
const lib = @import("sudoku_lib");

pub fn main() !void {
    var stdout_buf: [256]u8 = undefined;
    var stderr_buf: [256]u8 = undefined;
    var stdin_buf: [82]u8 = undefined;

    var stdout = std.fs.File.stdout().writer(&stdout_buf);
    var stderr = std.fs.File.stderr().writer(&stderr_buf);
    var stdin = std.fs.File.stdin().reader(&stdin_buf);

    try stdout.interface.print("Enter each sudoku puzzle as one line. Press Ctr-D to quit.\n", .{});
    try stdout.interface.flush();

    var game = lib.Game{};
    var timer = try std.time.Timer.start();
    var mini_timer = try std.time.Timer.start();
    outer_loop: while (true) : (game.clear()) {
        if (stdin.interface.takeDelimiterInclusive('\n')) |msg| {
            try stdout.interface.print("Input:       {s}\n", .{msg});
            try stdout.interface.flush();

            mini_timer.reset();
            for (0..81) |i| {
                switch (msg[i]) {
                    '.' => {},
                    '1'...'9' => |v| game.choose(i, v - '1'),
                    '\n' => {
                        try stderr.interface.print("Input too short\n", .{});
                        try stderr.interface.flush();
                        continue :outer_loop;
                    },
                    else => |c| {
                        try stderr.interface.print("Illegal character {c}\n", .{c});
                        try stderr.interface.flush();
                        continue :outer_loop;
                    },
                }
            }
            if (lib.eval(&game)) |_| {
                for (0..81) |i| {
                    game.board[i] += '1';
                }
                try stdout.interface.print("Solution:    {s}\n", .{game.board});
            } else |_| {
                try stdout.interface.print("Game cannot be solved.\n", .{});
            }
            const read = mini_timer.read() / std.time.ns_per_us;
            try stdout.interface.print("Time needed: {}µs.\n\n", .{read});
            try stdout.interface.flush();
        } else |err| switch (err) {
            error.StreamTooLong => {
                try stderr.interface.print("Input too long\n", .{});
                try stderr.interface.flush();
                _ = try stdin.interface.discardDelimiterInclusive('\n');
            },
            error.EndOfStream => break,
            else => |e| return e,
        }
    }

    const read = timer.read() / std.time.ns_per_ms;
    try stdout.interface.print("Total time needed: {}ms.\nBye\n", .{read});
    try stdout.interface.flush();
}
