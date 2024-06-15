const std = @import("std");

pub const Random = struct {
    random: std.Random.Random,
    
    const Self = @This();

    pub fn init() Self {
        const rng = std.rand.DefaultPrng.init(0);
        return Random {
            .random = rng.random(),
        };
    }

    pub fn rand_int(self: *const Self) i32 {
        return self.random.int(i32);
    }

    pub fn rand_float(self: *const Self) f32 {
        return self.random.float(f32);
    }

    pub fn rand_int_in_range(self: *const Self, x: i32, y: i32) i32 {
        const range = y - x;
        const rnd_num = self.random.float(f32);
        return @round((range * rnd_num) + x);
    }

    pub fn rand_float_in_range(self: *const Self, x: f32, y: f32) f32 {
        const range = y - x;
        const rnd_num = self.random.float(f32);
        return (range * rnd_num) + x;
    }

    pub fn rand_bool(self: *const Self) bool {
        return self.random.float(f32) > 0.5;
    }

    /// Returns a random float in the range -1 < n < 1
    pub fn random_clamped(self: *const Self) f32 {
        const rnd_num = self.random.float(f32);
        return (2.0 * rnd_num) - 1.0;
    }

    /// Return a floating point value normally distributed with mean = 0, stddev = 1.
    /// To use different parameters, use: floatNorm(...) * desiredStddev + desiredMean.
    pub fn rand_normal_distribution(self: *const Self) f32 {
        return self.random.floatNorm(f32);
    }
};