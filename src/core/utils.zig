const std = @import("std");

pub fn bufCopyZ(buf: []u8, source: []const u8) [:0]const u8 {
    std.mem.copyForwards(u8, buf, source);
    buf[source.len] = 0;
    return buf[0..source.len :0];
}



//
// pub fn get_exists_filename(directory: &Path, filename: &str) -> Result<PathBuf, Error> {
//     let path = directory.join(filename);
//     if path.is_file() {
//         return Ok(path);
//     }
//     let filepath = PathBuf::from(filename.replace('\\', "/"));
//     let filename = filepath.file_name().unwrap();
//     let path = directory.join(filename);
//     if path.is_file() {
//         return Ok(path);
//     }
//     Err(PathError(format!("filename not found: {:?}", filename.to_os_string())))
// }

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

pub fn removeRange(comptime T: type, list: *std.ArrayList(T), start: usize, end: usize) !void {
    if (start >= end or end >= list.len) {
        return error.InvalidRange;
    }
    const count = end - start + 1;

    // Call deinit on each item in the range
    for (start..end) |i| {
        list.items[i].deinit();
    }

    // Move the items to fill the gap
    for (end + 1..list.len) |i| {
        list.items[i - count] = list.items[i];
    }

    // Update the length of the list
    list.shrink(list.len - count);
}
