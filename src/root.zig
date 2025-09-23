fn FastUInt(comptime width: usize) type {
    return if (width <= @bitSizeOf(usize))
        usize
    else switch (@bitSizeOf(usize) - @clz(width)) {
        else => @compileError("No fast integer type found."),
        0 => u1,
        1 => u2,
        2 => u4,
        3 => u8,
        4 => u16,
        5 => u32,
        6 => u64,
        7 => u128,
        8 => u256,
    };
}

const FastU9 = FastUInt(9);

const lookup: [81][4]u8 = b: {
    var tmp: [81][4]u8 = undefined;
    for (0..3) |i| for (0..3) |j| for (0..3) |k| for (0..3) |l| {
        const row = i * 3 + k;
        const col = j * 3 + l;
        const sqr = i * 3 + j;
        const ant = k * 3 + l;
        tmp[i * 27 + j * 3 + k * 9 + l] = .{ row, col, sqr, ant };
    };
    break :b tmp;
};

const rev_lookup: [3][9][9]u8 = b: {
    var tmp: [3][9][9]u8 = undefined;
    for (0..81) |idx| {
        const i, const j, const k, const l = lookup[idx];
        tmp[0][i][j] = idx;
        tmp[1][j][i] = idx;
        tmp[2][k][l] = idx;
    }
    break :b tmp;
};

const ray_maker: [8]FastU9 = b: {
    var tmp: [8]FastU9 = .{0x1FF} ** 8;
    for (0..8) |i| {
        var f = i;
        while (f != 0) {
            const c = @ctz(f);
            f &= f - 1;
            tmp[7 - i] ^= 0b111 << 3 * c;
        }
    }
    break :b tmp;
};

const yar_maker: [8]FastU9 = b: {
    var tmp: [8]FastU9 = .{0x1FF} ** 8;
    for (0..8) |i| tmp[7 - i] ^= i ^ (i << 3) ^ (i << 6);
    break :b tmp;
};

const mini_lookup: [9][2]u8 = b: {
    var tmp: [9][2]u8 = undefined;
    for (0..9) |i| tmp[i] = .{ i / 3, i % 3 };
    break :b tmp;
};

fn get_ray_r(mask: FastU9, i: usize) FastU9 {
    const j = 0b111 & mask >> @intCast(3 * i);
    return ray_maker[j];
}

fn get_ray_c(mask: FastU9, i: usize) FastU9 {
    const j = 0b111 & 0b10101 * (0b100100100 & mask << @intCast(2 - i)) >> 6;
    return ray_maker[j];
}

fn get_yar_r(mask: FastU9, i: usize) FastU9 {
    const j = 0b111 & mask >> @intCast(3 * i);
    return yar_maker[j];
}

const EvalError = error{Unsolvable};

pub fn eval(game: *Game) EvalError!void {
    const showbestfree = game.showbestfree();
    switch (showbestfree) {
        .solved => return,
        .failed => return error.Unsolvable,
        .pickidx => |ok| {
            const idx, var cands = ok;
            while (cands != 0) : (cands &= cands - 1) {
                const c = @ctz(cands);
                game.choose(idx, c);
                eval(game) catch {
                    game.unchoose(idx);
                    continue;
                };
                return;
            }
        },
        .pickval => |ok| {
            const vti, var cands = ok;
            while (cands != 0) : (cands &= cands - 1) {
                const c = @ctz(cands);
                const idx = game.choose_alt(vti, c);
                eval(game) catch {
                    game.unchoose(idx);
                    continue;
                };
                return;
            }
        },
    }
    return error.Unsolvable;
}

const ShowKinds = union(enum) {
    pickidx: struct { u8, FastU9 },
    pickval: struct { [2]u8, FastU9 },
    failed,
    solved,
};

pub const Game = struct {
    board: [81]u8 = undefined,
    frees: [4]u128 = .{0x1FFFFFFFFFFFFFFFFFFFF} ** 4,
    occupied: [3][9]FastU9 = .{.{0x1FF} ** 9} ** 3,
    house_masks: [3][9]FastU9 = .{.{0x1FF} ** 9} ** 3,
    value_masks: [9][3]FastU9 = .{.{0x1FF} ** 3} ** 9,

    pub fn clear(self: *Game) void {
        self.frees = .{0x1FFFFFFFFFFFFFFFFFFFF} ** 4;
        self.occupied = .{.{0x1FF} ** 9} ** 3;
        self.house_masks = .{.{0x1FF} ** 9} ** 3;
        self.value_masks = .{.{0x1FF} ** 3} ** 9;
    }

    pub fn choose(self: *Game, idx: usize, val: usize) void {
        self.board[idx] = @intCast(val);
        self.update_masks(idx, val);
    }

    fn choose_alt(self: *Game, vht: [2]u8, idx: usize) usize {
        const ht, const id = vht;
        const hi, const val, _, _ = lookup[id];
        const true_idx = rev_lookup[ht][hi][idx];
        self.choose(true_idx, val);
        return true_idx;
    }

    fn unchoose(self: *Game, idx: usize) void {
        const val = self.board[idx];
        self.board[idx] = 0;
        self.update_masks(idx, val);
    }

    fn update_masks(self: *Game, idx: usize, val: usize) void {
        self.frees[3] ^= @as(u128, 1) << @intCast(idx);
        const mask = @as(FastU9, 1) << @intCast(val);
        const houses = lookup[idx];
        inline for (0..3) |ht| {
            const hi = houses[ht];
            self.frees[ht] ^= @as(u128, 1) << @intCast(hi * 9 + val);
            self.house_masks[ht][hi] ^= mask;
            self.occupied[ht][hi] ^= @as(FastU9, 1) << @intCast(houses[ht ^ 1]);
            self.value_masks[val][ht] ^= @as(FastU9, 1) << @intCast(hi);
        }
    }

    fn showbestfree(self: *const Game) ShowKinds {
        var best_value: ShowKinds = .solved;
        var best_weight: usize = 10;

        {
            var f = self.frees[3];
            while (f != 0) : (f &= f - 1) {
                const i = @ctz(f);
                const c = self.candidates(i);
                if (c == 0) return .failed;
                switch (@popCount(c)) {
                    1 => return ShowKinds{ .pickidx = .{ i, c } },
                    else => |w| if (w < best_weight) {
                        best_weight = w;
                        best_value = ShowKinds{ .pickidx = .{ i, c } };
                    },
                }
            }
        }

        inline for (0..3) |t| {
            var f = self.frees[t];
            while (f != 0) : (f &= f - 1) {
                const i = @ctz(f);
                const c = self.pos_indices(t, i);
                if (c == 0) return .failed;
                switch (@popCount(c)) {
                    1 => return ShowKinds{ .pickval = .{ .{ t, i }, c } },
                    else => |w| if (w < best_weight) {
                        best_weight = w;
                        best_value = ShowKinds{ .pickval = .{ .{ t, i }, c } };
                    },
                }
            }
        }

        return best_value;
    }

    fn candidates(self: *const Game, idx: usize) FastU9 {
        const i, const j, const k, _ = lookup[idx];
        return self.house_masks[0][i] & self.house_masks[1][j] & self.house_masks[2][k];
    }

    fn pos_indices(self: *const Game, comptime ht: usize, id: usize) FastU9 {
        const hi, const val, _, _ = lookup[id];
        const rwhi, const clhi = mini_lookup[hi];

        return self.occupied[ht][hi] &
            switch (ht) {
                0 => self.value_masks[val][1] & get_ray_r(self.value_masks[val][2], rwhi),
                1 => self.value_masks[val][0] & get_ray_c(self.value_masks[val][2], rwhi),
                2 => get_ray_r(self.value_masks[val][0], rwhi) & get_yar_r(self.value_masks[val][1], clhi),
                else => unreachable,
            };
    }
};
