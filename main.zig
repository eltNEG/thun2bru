const std = @import("std");
const json = std.json;
const fs = std.fs;

const ThunderTypes = @import("./types.zig");
const ThunderJson = ThunderTypes.ThunderJson;
const BrunoTypes = @import("./types_bruno.zig");

const BrunoReqMethod = BrunoTypes.BrunoReqMethod;
const BrunoMeta = BrunoTypes.BrunoMeta;
const BrunoReq = BrunoTypes.BrunoReq;
const BrunoHeader = BrunoTypes.BrunoHeader;
const BrunoBody = BrunoTypes.BrunoBody;
const BrunoHeaders = BrunoTypes.BrunoHeaders;
const BrunoEnvs = BrunoTypes.BrunoEnvVariables;

fn format(comptime template: []const u8, T: type, meta: T) ![]u8 {
    var buf: [128]u8 = undefined;
    return try std.fmt.bufPrint(&buf, template, .{ meta.name, meta.type, meta.seq });
}

fn run(allocator: std.mem.Allocator, thunder: ThunderJson) !void {
    const cwd = fs.cwd();

    const name = thunder.collectionName orelse thunder.environmentName orelse {
        std.debug.print("No collection name or environment name found\n", .{});
        return;
    };

    const output = try allocator.alloc(u8, name.len);
    defer allocator.free(output);
    _ = std.mem.replace(u8, name, " ", "_", output);
    const basePath = try std.mem.join(allocator, "", &[_][]const u8{ "result/", output, "/" });
    defer allocator.free(basePath);
    cwd.makePath(basePath) catch |err| {
        if (err != fs.Dir.MakeError.PathAlreadyExists) {
            return;
        }
    };

    if (thunder.variables) |variables| {
        const filename = try std.mem.join(allocator, "", &[_][]const u8{ basePath, name, ".bru" });
        defer allocator.free(filename);

        const file = try cwd.createFile(filename, .{});
        defer file.close();

        const envVars = try allocator.alloc(BrunoEnvs.EnvVar, variables.len);
        defer allocator.free(envVars);
        for (variables, 0..) |envVar, l| {
            const __envVar = BrunoEnvs.EnvVar{
                .name = envVar.name,
                .value = envVar.value,
            };
            envVars[l] = __envVar;
        }

        const _env = BrunoEnvs{
            .variables = envVars,
        };

        const m = try _env.format(allocator);
        defer allocator.free(m);

        // write to file
        _ = try file.writeAll(m);
    }

    if (thunder.requests == null) {
        return;
    }

    for (thunder.requests.?, 0..) |req, i| {
        const _meta = BrunoMeta{
            .name = req.name,
            .type = "http",
            .seq = @intCast(i + 1),
        };

        const _method = try allocator.alloc(u8, req.method.len);
        defer allocator.free(_method);

        for (req.method, 0..) |c, j| {
            _method[j] = std.ascii.toLower(c);
        }

        const method = std.meta.stringToEnum(BrunoReqMethod, _method) orelse .get;

        const body = BrunoBody{
            .query = blk: {
                if (req.params != null) {
                    break :blk req.params.?;
                } else {
                    break :blk null;
                }
            },
            .body = blk: {
                if (req.body != null) {
                    break :blk (req.body.?).raw;
                } else {
                    break :blk null;
                }
            },
            .method = method,
        };

        const _req = BrunoReq{
            .url = req.url,
            .method = method,
        };

        const __headers = try allocator.alloc(BrunoHeader, req.headers.len);
        defer allocator.free(__headers);

        for (req.headers, 0..) |header, ii| {
            const _header = BrunoHeader{
                .key = header.name,
                .value = header.value,
            };
            __headers[ii] = _header;
        }

        const _headers = BrunoHeaders{
            .headers = __headers,
        };

        const m = try _meta.format(allocator);
        defer allocator.free(m);

        const r = try _req.format(allocator);
        defer allocator.free(r);

        const b = try body.format(allocator);
        defer allocator.free(b);

        const h = try _headers.format(allocator);
        defer allocator.free(h);

        const f = try allocator.alloc(u8, m.len + r.len + b.len + h.len);
        defer allocator.free(f);

        @memcpy(f[0..m.len], m);
        @memcpy(f[m.len .. m.len + r.len], r);
        @memcpy(f[m.len + r.len .. m.len + r.len + b.len], b);
        @memcpy(f[m.len + r.len + b.len .. f.len], h);

        // write to file
        const filename = try std.mem.join(allocator, "", &[_][]const u8{ basePath, req.name, ".bru" });
        defer allocator.free(filename);

        const file = try cwd.createFile(filename, .{});
        defer file.close();

        _ = try file.writeAll(f);
    }
    std.debug.print("Done\n", .{});
}

pub fn parseFile(alloc: std.mem.Allocator, filepath: []const u8) ![]u8 {
    // Open the file
    const file = try fs.cwd().openFile(filepath, .{});
    defer file.close();

    // Read the file content
    const content = try file.readToEndAlloc(alloc, 1024 * 1024); // 1MB limit

    return content;
}

fn fmtt(b: BrunoTypes.BrunoAll) !void {
    std.debug.print("{s}", .{try b.format()});
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        std.debug.print("Usage: `$run -- file.json`\n", .{});
        return;
    }

    std.debug.print("Converting {s} to bru\n", .{args[1]});

    const thunderJson = try parseFile(allocator, args[1]);
    defer allocator.free(thunderJson);
    const parsed = try json.parseFromSlice(ThunderJson, allocator, thunderJson, .{
        .ignore_unknown_fields = true,
        .duplicate_field_behavior = .use_first,
    });
    defer parsed.deinit();

    const parsedThunderJson = parsed.value;

    try run(allocator, parsedThunderJson);

    // const m = BrunoTypes.BrunoAll{ .Meta = .{
    //     .name = "test",
    //     .type = "http",
    //     .seq = 1,
    // } };

    // try fmtt(m);
}
