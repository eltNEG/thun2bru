const std = @import("std");
const ThunderJsonRequestsQueryParams = @import("./types.zig").ThunderJsonRequestsQueryParams;

pub const BrunoReqMethod = enum {
    get,
    post,
    delete,
    put,

    const Self = @This();

    pub fn str(self: Self) []const u8 {
        return switch (self) {
            .get => return "get",
            .post => return "post",
            .delete => return "delete",
            .put => return "put",
        };
    }
};

pub const BrunoMeta = struct {
    name: []const u8,
    type: []const u8,
    seq: u32,

    const template =
        \\meta {{
        \\  name: {s}
        \\  type: {s}
        \\  seq: {d}
        \\}}
        \\
        \\
    ;

    const template_len_extra = 11;

    pub fn format(self: BrunoMeta, allocator: std.mem.Allocator) ![]u8 {
        const seq_digits = NumDigits(u32, self.seq);
        const n = self.name.len + self.type.len + seq_digits + template.len - template_len_extra;
        const buf = try allocator.alloc(u8, n);
        return try std.fmt.bufPrint(buf, template, .{ self.name, self.type, self.seq });
    }
};

fn NumDigits(T: type, n: T) T {
    if (n == 0) {
        return 1;
    }
    return 1 + std.math.log10(n);
}

test "NumDigits" {
    try std.testing.expect(NumDigits(u32, 0) == 1);
    try std.testing.expect(NumDigits(u32, 1) == 1);
    try std.testing.expect(NumDigits(u32, 9) == 1);
    try std.testing.expect(NumDigits(u32, 10) == 2);
    try std.testing.expect(NumDigits(u32, 11) == 2);
    try std.testing.expect(NumDigits(u32, 99) == 2);
    try std.testing.expect(NumDigits(u32, 100) == 3);
    try std.testing.expect(NumDigits(u32, 101) == 3);
    try std.testing.expect(NumDigits(u32, 999) == 3);
    try std.testing.expect(NumDigits(u32, 1000) == 4);
}

pub const BrunoReq = struct {
    url: []const u8,
    method: BrunoReqMethod,

    const brunoReqTemplate =
        \\{s} {{
        \\  url: {s}
        \\  body: json
        \\  auth: none
        \\}}
        \\
        \\
    ;

    const template_len_extra = 8;

    pub fn format(self: BrunoReq, allocator: std.mem.Allocator) ![]u8 {
        const method_str = self.method.str();
        const buf = try allocator.alloc(u8, method_str.len + self.url.len + brunoReqTemplate.len - template_len_extra);
        return try std.fmt.bufPrint(buf, brunoReqTemplate, .{ method_str, self.url });
    }
};

pub const BrunoHeader = struct {
    key: []const u8,
    value: []const u8,
};

pub const BrunoBody = struct {
    query: ?[]ThunderJsonRequestsQueryParams,
    body: ?[]const u8,
    method: BrunoReqMethod,

    const brunoParamsQueryTemplate =
        \\params:query {{
        \\{s}
        \\}}
        \\
        \\
    ;

    const query_template_len_extra = 5;

    const brunoJsonBodyTemplate =
        \\body:json {{
        \\  {s}  {c}
        \\}}
        \\
        \\
    ;

    const json_body_template_len_extra = 8;

    pub fn format(self: BrunoBody, allocator: std.mem.Allocator) ![]u8 {
        switch (self.method) {
            .get, .delete => {
                var _buf = std.ArrayList(u8).init(allocator);
                defer _buf.deinit();

                const queries = self.query orelse return "";
                for (queries, 0..) |param, k| {
                    const new_line = if (k != queries.len - 1) "\n" else "";
                    const disabled = if (param.isDisabled.?) "~" else "";
                    const _n = param.name.len + param.value.len + 4 + new_line.len + disabled.len;
                    const res = try allocator.alloc(u8, _n);
                    defer allocator.free(res);
                    const _res = try std.fmt.bufPrint(res, "  {s}{s}: {s}{s}", .{ disabled, param.name, param.value, new_line });
                    try _buf.appendSlice(_res);
                }

                const buf = try allocator.alloc(u8, brunoParamsQueryTemplate.len + _buf.items.len - query_template_len_extra);
                return try std.fmt.bufPrint(buf, brunoParamsQueryTemplate, .{_buf.items});
            },
            else => {
                const body = self.body orelse return "";
                const buf = try allocator.alloc(u8, brunoJsonBodyTemplate.len + body.len - json_body_template_len_extra);
                return try std.fmt.bufPrint(buf, brunoJsonBodyTemplate, .{ body[0 .. body.len - 1], body[body.len - 1] });
            },
        }
    }
};

pub const BrunoHeaders = struct {
    headers: []BrunoHeader,

    const brunoHeadersTemplate =
        \\headers {{
        \\{s}
        \\}}
    ;

    const template_len_extra = 5;

    pub fn format(self: BrunoHeaders, allocator: std.mem.Allocator) ![]u8 {
        if (self.headers.len == 0) {
            return "";
        }
        var _buf = std.ArrayList(u8).init(allocator);
        defer _buf.deinit();

        for (self.headers, 0..) |header, k| {
            const new_line = if (k != self.headers.len - 1) "\n" else "";
            const _n = header.key.len + header.value.len + 4 + new_line.len;
            const res = try allocator.alloc(u8, _n);
            const _res = try std.fmt.bufPrint(res, "  {s}: {s}{s}", .{ header.key, header.value, new_line });
            defer allocator.free(_res);
            try _buf.appendSlice(_res);
        }

        const buf0 = try allocator.alloc(u8, brunoHeadersTemplate.len + _buf.items.len - template_len_extra);
        return try std.fmt.bufPrint(buf0, brunoHeadersTemplate, .{_buf.items});
    }
};

pub const BrunoEnvVariables = struct {
    variables: []EnvVar,

    pub const EnvVar = struct {
        name: []const u8,
        value: []const u8,
    };

    const template =
        \\vars {{
        \\{s}
        \\}}
    ;

    const template_len_extra = 5;

    pub fn format(self: BrunoEnvVariables, allocator: std.mem.Allocator) ![]u8 {
        var arr = std.ArrayList(u8).init(allocator);
        defer arr.deinit();

        if (self.variables.len == 0) {
            return "";
        }

        for (self.variables, 0..) |envVar, k| {
            const new_line = if (k != self.variables.len - 1) "\n" else "";
            const _n = envVar.name.len + envVar.value.len + 4 + new_line.len;
            const res = try allocator.alloc(u8, _n);
            defer allocator.free(res);
            const _res = try std.fmt.bufPrint(res, "  {s}: {s}{s}", .{ envVar.name, envVar.value, new_line });
            try arr.appendSlice(_res);
        }
        const buf0 = try allocator.alloc(u8, template.len + arr.items.len - template_len_extra);
        return try std.fmt.bufPrint(buf0, template, .{arr.items});
    }
};

pub const BrunoAll = union(enum) {
    Meta: BrunoMeta,
    Req: BrunoReq,
    Headers: BrunoHeaders,
    Body: BrunoBody,

    pub fn format(self: BrunoAll, allocator: std.mem.Allocator) ![]u8 {
        switch (self) {
            .Meta => return self.Meta.format(allocator),
            .Req => return self.Req.format(allocator),
            .Headers => return self.Headers.format(allocator),
            .Body => return self.Body.format(allocator),
        }
    }
};
