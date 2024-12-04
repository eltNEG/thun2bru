// thunder

pub const ThunderJsonRequestsHeaders = struct {
    name: []const u8,
    value: []const u8,
};

pub const ThunderJsonRequestsQueryParams = struct {
    name: []const u8,
    value: []const u8,
    isDisabled: ?bool = false,
    isPath: bool,
};

pub const ThunderJsonRequestsBody = struct {
    type: []const u8,
    raw: []const u8,
    form: ?[][]const u8 = null,
};

pub const ThunderJsonRequests = struct {
    headers: []ThunderJsonRequestsHeaders,
    params: ?[]ThunderJsonRequestsQueryParams = null,
    body: ?ThunderJsonRequestsBody = null,

    _id: []const u8,
    colId: []const u8,
    containerId: []const u8,
    name: []const u8,
    url: []const u8,
    method: []const u8,
    sortNum: f32,
    created: []const u8,
    modified: []const u8,
};

const ThunderEnvVariables = struct {
    name: []const u8,
    value: []const u8,
};

pub const ThunderJson = struct {
    clientName: []const u8,
    collectionName: ?[]const u8 = null,
    environmentName: ?[]const u8 = null,
    variables: ?[]ThunderEnvVariables = null,
    // collectionId: []const u8,
    dateExported: []const u8,
    version: []const u8,
    // folders: ?[][]const u8 = null,
    requests: ?[]ThunderJsonRequests = null,
    ref: []const u8,
};
