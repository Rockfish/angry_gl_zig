const std = @import("std");

pub fn bufCopyZ(buf: []u8, source: []const u8) [:0]const u8 {
    std.mem.copyForwards(u8, buf, source);
    buf[source.len] = 0;
    return buf[0..source.len :0];
}

pub fn retain(comptime T: type, list: *std.ArrayList(?*T), testFn: *const fn (a: *T) bool, allocator: std.mem.Allocator) !void {
    _ = allocator;
    const length = list.items.len;
    var i: usize = 0;
    var f: usize = 0;
    var flag = true;
    var count: usize = 0;

    while (true) {
        // test if false
        if (i < length and (list.items[i] == null or !testFn(list.items[i].?))) {
            if (flag) {
                f = i;
                flag = false;
            }

            while (i < length and (list.items[i] == null or !testFn(list.items[i].?))) {
                i += 1;
            }

            // move true to here
            if (i < length) {
                const delete = list.items[f];
                list.items[f] = list.items[i];
                list.items[i] = null;

                if (delete != null) {
                    delete.?.deinit();
                    // allocator.destroy(delete.?);
                }
                f += 1;
                count += 1;
            }
        } else {
            count += 1;
            // fill in gaps
            if (i < length and f < i and flag == false) {
                const delete = list.items[f];
                list.items[f] = list.items[i];
                list.items[i] = null;

                if (delete != null) {
                    delete.?.deinit();
                    // allocator.destroy(delete.?);
                }
                f += 1;
            }
        }
        i += 1;
        if (i >= length) {
            break;
        }
    }

    // delete remainder
    if (count < length) {
        for (list.items[count..length]) |d| {
            if (d != null) {
                d.?.deinit();
                // allocator.destroy(d.?);
            }
        }
        list.items = list.items[0..count];
    }
}
