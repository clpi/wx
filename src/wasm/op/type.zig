const std = @import("std");

pub const OpType = enum(u4) {
    control,
    parametric,
    variable,
    memory,
    numeric,
};
