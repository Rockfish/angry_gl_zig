const std = @import("std");

pub const Random = struct {
    prng: std.Random.Xoshiro256,
    
    const Self = @This();

    pub fn init() Self {
        // rand.rng = std.rand.Random.init( &rand.xoroshiro, std.rand.Xoroshiro128.fill);
        return  Self {
            .prng = std.rand.DefaultPrng.init(42),
        };
    }

    pub fn randInt(self: *Self) i32 {
        return self.prng.random().int(i32);
    }

    pub fn randFloat(self: *Self) f32 {
        return self.prng.random().float(f32);
    }

    pub fn randIntInRange(self: *Self, x: i32, y: i32) i32 {
        const range = y - x;
        const rnd_num = self.prng.random().float(f32);
        return @round((range * rnd_num) + x);
    }

    pub fn randFloatInRange(self: *Self, x: f32, y: f32) f32 {
        const range = y - x;
        const rnd_num = self.prng.random().float(f32);
        return (range * rnd_num) + x;
    }

    pub fn randBool(self: *Self) bool {
        return self.prng.random().float(f32) > 0.5;
    }

    /// Returns a random float in the range -1 < n < 1
    pub fn randClamped(self: *Self) f32 {
        const rnd_num = self.prng.random().float(f32);
        return (2.0 * rnd_num) - 1.0;
    }

    /// Return a floating point value normally distributed with mean = 0, stddev = 1.
    /// To use different parameters, use: floatNorm(...) * desiredStddev + desiredMean.
    pub fn randNormalDistribution(self: *Self) f32 {
        return self.prng.random().floatNorm(f32);
    }
};

test "random.float" {
    var random = Random.init();

    for (0..10) |i| {
        const r = random.randFloat();
        std.debug.print("{d} : {d}\n", .{i, r});
    }
}

test "random.float2" {
    var xoroshiro = std.rand.Xoroshiro128.init(9273853284918);
    const rng = std.rand.Random.init(
        &xoroshiro,
        std.rand.Xoroshiro128.fill,
    );

    for (0..10) |i| {
        const r = rng.float(f32);
        std.debug.print("{d} : {d}\n", .{i, r});
    }
}

test "random.prig" {
    var prng = std.rand.DefaultPrng.init(42);

    for (0..10) |i| {
        const r = prng.random().float(f32);
        std.debug.print("{d} : {d}\n", .{i, r});
    }
}
