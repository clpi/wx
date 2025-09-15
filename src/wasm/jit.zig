const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;
const Value = @import("value.zig").Value;
const ValueType = @import("value.zig").Type;
const Module = @import("module.zig");

// JIT compilation strategy:
// 1. Profile function execution counts during interpretation
// 2. Compile hot functions to native x64 code
// 3. Use register-based calling convention for performance
// 4. Implement inline caching for dynamic dispatch

pub const JIT = struct {
    const Self = @This();

    allocator: Allocator,
    // Executable memory region for generated code
    code_memory: []u8,
    code_offset: usize,
    // Function execution counters for profiling
    function_counters: std.AutoHashMap(u32, u32),
    // Compiled function cache
    compiled_functions: std.AutoHashMap(u32, CompiledFunction),
    // Compilation threshold - lower for faster JIT triggering
    compilation_threshold: u32 = 3,
    // Platform information
    target_arch: std.Target.Cpu.Arch,

    pub const CompiledFunction = struct {
        entry_point: *const fn (*Runtime, []Value) Value,
        code_size: usize,
        register_usage: RegisterMask,
    };

    pub const RegisterMask = packed struct {
        rax: bool = false,
        rcx: bool = false,
        rdx: bool = false,
        rbx: bool = false,
        rsp: bool = false,
        rbp: bool = false,
        rsi: bool = false,
        rdi: bool = false,
        r8: bool = false,
        r9: bool = false,
        r10: bool = false,
        r11: bool = false,
        r12: bool = false,
        r13: bool = false,
        r14: bool = false,
        r15: bool = false,
    };

    // x64 registers for WebAssembly value stack
    pub const Register = enum(u8) {
        rax = 0,
        rcx = 1,
        rdx = 2,
        rbx = 3,
        rsp = 4,
        rbp = 5,
        rsi = 6,
        rdi = 7,
        r8 = 8,
        r9 = 9,
        r10 = 10,
        r11 = 11,
        r12 = 12,
        r13 = 13,
        r14 = 14,
        r15 = 15,

        pub fn encode(self: Register) u8 {
            return @intFromEnum(self);
        }
    };

    // Code generation buffer
    pub const CodeGen = struct {
        buffer: std.ArrayList(u8),
        allocator: Allocator,
        // Stack simulation for register allocation
        value_stack: std.ArrayList(StackSlot),
        // Register allocation state
        registers: [16]?StackSlot,
        next_spill_offset: i32,
        // Control flow stack for tracking blocks/loops
        control_stack: std.ArrayList(ControlFrame),

        pub const ControlFrame = struct {
            kind: ControlKind,
            start_label: u32,
            end_label: ?u32,
            break_label: ?u32,
            stack_height: usize,

            pub const ControlKind = enum {
                block,
                loop,
                if_block,
            };
        };

        pub const StackSlot = struct {
            type: ValueType,
            location: Location,

            pub const Location = union(enum) {
                register: Register,
                stack: i32, // offset from rbp
                constant: i64,
            };
        };

        pub fn init(allocator: Allocator) CodeGen {
            return CodeGen{
                .buffer = std.ArrayList(u8){},
                .allocator = allocator,
                .value_stack = std.ArrayList(StackSlot){},
                .registers = [_]?StackSlot{null} ** 16,
                .next_spill_offset = -8,
                .control_stack = std.ArrayList(ControlFrame){},
            };
        }

        pub fn deinit(self: *CodeGen) void {
            self.buffer.deinit(self.allocator);
            self.value_stack.deinit(self.allocator);
            self.control_stack.deinit(self.allocator);
        }

        // Allocate a register for a value
        pub fn allocateRegister(self: *CodeGen, value_type: ValueType) !Register {
            // Simple linear scan register allocation
            // In order of preference for x64
            const preferred_order = [_]Register{ .rax, .rcx, .rdx, .rbx, .rsi, .rdi, .r8, .r9, .r10, .r11 };

            for (preferred_order) |reg| {
                if (self.registers[@intFromEnum(reg)] == null) {
                    self.registers[@intFromEnum(reg)] = StackSlot{
                        .type = value_type,
                        .location = .{ .register = reg },
                    };
                    return reg;
                }
            }

            // Need to spill a register
            const victim_reg = preferred_order[0]; // Spill rax
            try self.spillRegister(victim_reg);
            self.registers[@intFromEnum(victim_reg)] = StackSlot{
                .type = value_type,
                .location = .{ .register = victim_reg },
            };
            return victim_reg;
        }

        pub fn spillRegister(self: *CodeGen, reg: Register) !void {
            if (self.registers[@intFromEnum(reg)]) |_| {
                // Move register to stack
                try self.emitMov(.{ .stack = self.next_spill_offset }, .{ .register = reg });
                self.registers[@intFromEnum(reg)] = null;
                self.next_spill_offset -= 8;
            }
        }

        // Emit x64 instructions
        pub fn emitMov(self: *CodeGen, dst: StackSlot.Location, src: StackSlot.Location) !void {
            switch (dst) {
                .register => |dst_reg| switch (src) {
                    .register => |src_reg| {
                        // mov dst_reg, src_reg
                        try self.emitRexPrefix(true, dst_reg, src_reg);
                        try self.buffer.append(self.allocator,0x89); // mov r/m64, r64
                        try self.buffer.append(self.allocator,0xC0 | (src_reg.encode() << 3) | dst_reg.encode());
                    },
                    .constant => |value| {
                        // mov dst_reg, imm64
                        try self.emitRexPrefix(true, dst_reg, .rax);
                        try self.buffer.append(self.allocator,0xB8 + dst_reg.encode()); // mov r64, imm64
                        try self.buffer.appendSlice(self.allocator,std.mem.asBytes(&value));
                    },
                    .stack => |offset| {
                        // mov dst_reg, [rbp + offset]
                        try self.emitRexPrefix(true, dst_reg, .rbp);
                        try self.buffer.append(self.allocator,0x8B); // mov r64, r/m64
                        try self.emitModRM(0b10, dst_reg.encode(), 0b101); // [rbp + disp32]
                        try self.buffer.appendSlice(self.allocator,std.mem.asBytes(&offset));
                    },
                },
                .stack => |dst_offset| switch (src) {
                    .register => |src_reg| {
                        // mov [rbp + dst_offset], src_reg
                        try self.emitRexPrefix(true, src_reg, .rbp);
                        try self.buffer.append(self.allocator,0x89); // mov r/m64, r64
                        try self.emitModRM(0b10, src_reg.encode(), 0b101); // [rbp + disp32]
                        try self.buffer.appendSlice(self.allocator,std.mem.asBytes(&dst_offset));
                    },
                    else => unreachable, // Not supported
                },
                else => unreachable,
            }
        }

        pub fn emitAdd(self: *CodeGen, dst_reg: Register, src_reg: Register) !void {
            // add dst_reg, src_reg
            try self.emitRexPrefix(true, dst_reg, src_reg);
            try self.buffer.append(self.allocator,0x01); // add r/m64, r64
            try self.buffer.append(self.allocator,0xC0 | (src_reg.encode() << 3) | dst_reg.encode());
        }

        pub fn emitSub(self: *CodeGen, dst_reg: Register, src_reg: Register) !void {
            // sub dst_reg, src_reg
            try self.emitRexPrefix(true, dst_reg, src_reg);
            try self.buffer.append(self.allocator,0x29); // sub r/m64, r64
            try self.buffer.append(self.allocator,0xC0 | (src_reg.encode() << 3) | dst_reg.encode());
        }

        pub fn emitMul(self: *CodeGen, reg: Register) !void {
            // imul rax, reg (result in rax)
            try self.emitRexPrefix(true, .rax, reg);
            try self.buffer.append(self.allocator,0x0F);
            try self.buffer.append(self.allocator,0xAF);
            try self.buffer.append(self.allocator,0xC0 | (0 << 3) | reg.encode());
        }

        pub fn emitPush(self: *CodeGen, reg: Register) !void {
            if (reg.encode() >= 8) {
                try self.buffer.append(self.allocator,0x41); // REX.B
            }
            try self.buffer.append(self.allocator,0x50 + (reg.encode() & 7));
        }

        pub fn emitPop(self: *CodeGen, reg: Register) !void {
            if (reg.encode() >= 8) {
                try self.buffer.append(self.allocator,0x41); // REX.B
            }
            try self.buffer.append(self.allocator,0x58 + (reg.encode() & 7));
        }

        pub fn emitRet(self: *CodeGen) !void {
            try self.buffer.append(self.allocator,0xC3);
        }

        pub fn emitCmp(self: *CodeGen, reg1: Register, reg2: Register) !void {
            // cmp reg1, reg2
            try self.emitRexPrefix(true, reg1, reg2);
            try self.buffer.append(self.allocator,0x39); // cmp r/m64, r64
            try self.buffer.append(self.allocator,0xC0 | (reg2.encode() << 3) | reg1.encode());
        }

        pub fn emitJz(self: *CodeGen, offset: i32) !void {
            // jz rel32
            try self.buffer.append(self.allocator,0x0F);
            try self.buffer.append(self.allocator,0x84);
            try self.buffer.appendSlice(self.allocator,std.mem.asBytes(&offset));
        }

        pub fn emitJmp(self: *CodeGen, offset: i32) !void {
            // jmp rel32
            try self.buffer.append(self.allocator,0xE9);
            try self.buffer.appendSlice(self.allocator,std.mem.asBytes(&offset));
        }

        pub fn emitLabel(self: *CodeGen) u32 {
            return @intCast(self.buffer.items.len);
        }

        pub fn patchJump(self: *CodeGen, jump_pos: u32, target_pos: u32) !void {
            const offset = @as(i32, @intCast(target_pos)) - @as(i32, @intCast(jump_pos)) - 4;
            @memcpy(self.buffer.items[jump_pos..jump_pos + 4], std.mem.asBytes(&offset));
        }

        pub fn emitSetcc(self: *CodeGen, condition: u8, reg: Register) !void {
            // setcc r/m8
            if (reg.encode() >= 8) {
                try self.buffer.append(self.allocator,0x41); // REX.B
            }
            try self.buffer.append(self.allocator,0x0F);
            try self.buffer.append(self.allocator,condition);
            try self.buffer.append(self.allocator,0xC0 | (reg.encode() & 7));
        }

        pub fn emitXor(self: *CodeGen, dst_reg: Register, src_reg: Register) !void {
            // xor dst_reg, src_reg (useful for zeroing registers)
            try self.emitRexPrefix(true, dst_reg, src_reg);
            try self.buffer.append(self.allocator,0x31); // xor r/m64, r64
            try self.buffer.append(self.allocator,0xC0 | (src_reg.encode() << 3) | dst_reg.encode());
        }

        pub fn emitTest(self: *CodeGen, reg1: Register, reg2: Register) !void {
            // test reg1, reg2
            try self.emitRexPrefix(true, reg1, reg2);
            try self.buffer.append(self.allocator,0x85); // test r/m64, r64
            try self.buffer.append(self.allocator,0xC0 | (reg2.encode() << 3) | reg1.encode());
        }

        // Advanced peephole optimizations
        pub fn optimizeConstantFolding(_: *CodeGen) void {
            // Constant folding is now handled in arithmetic operations
        }

        // Optimize mov operations - avoid redundant moves
        pub fn emitOptimizedMov(self: *CodeGen, dst: StackSlot.Location, src: StackSlot.Location) !void {
            // Skip mov if source and destination are the same register
            if (dst == .register and src == .register and dst.register == src.register) {
                return;
            }
            try self.emitMov(dst, src);
        }

        // Optimize zero operations using xor
        pub fn emitOptimizedZero(self: *CodeGen, reg: Register) !void {
            try self.emitXor(reg, reg); // xor reg, reg is faster than mov reg, 0
        }

        pub fn emitFunctionPrologue(self: *CodeGen) !void {
            // push rbp
            try self.emitPush(.rbp);
            // mov rbp, rsp
            try self.emitMov(.{ .register = .rbp }, .{ .register = .rsp });
        }

        pub fn emitFunctionEpilogue(self: *CodeGen) !void {
            // mov rsp, rbp
            try self.emitMov(.{ .register = .rsp }, .{ .register = .rbp });
            // pop rbp
            try self.emitPop(.rbp);
            // ret
            try self.emitRet();
        }

        fn emitRexPrefix(self: *CodeGen, is_64bit: bool, dst_reg: Register, src_reg: Register) !void {
            var rex: u8 = 0x40;
            if (is_64bit) rex |= 0x08; // REX.W
            if (dst_reg.encode() >= 8) rex |= 0x04; // REX.R
            if (src_reg.encode() >= 8) rex |= 0x01; // REX.B
            if (rex != 0x40) try self.buffer.append(self.allocator,rex);
        }

        fn emitModRM(self: *CodeGen, mod: u8, reg: u8, rm: u8) !void {
            try self.buffer.append(self.allocator,(mod << 6) | ((reg & 7) << 3) | (rm & 7));
        }
    };

    pub fn init(allocator: Allocator) !Self {
        // Allocate executable memory (16MB initially)
        const code_size = 16 * 1024 * 1024;
        const code_memory = try allocator.alloc(u8, code_size);

        // Make memory executable on supported platforms
        // Note: Skip mprotect for now on macOS due to system security restrictions
        // In production, this would need proper entitlements or alternative approaches
        var memory_executable = false;
        if (builtin.os.tag != .windows and builtin.os.tag != .macos) {
            const result = std.c.mprotect(@ptrCast(@alignCast(code_memory.ptr)), code_memory.len, std.c.PROT.READ | std.c.PROT.WRITE | std.c.PROT.EXEC);
            if (result == 0) {
                memory_executable = true;
            }
            // Continue even if mprotect fails - JIT will fallback to interpreter
        }

        return Self{
            .allocator = allocator,
            .code_memory = code_memory,
            .code_offset = 0,
            .function_counters = std.AutoHashMap(u32, u32).init(allocator),
            .compiled_functions = std.AutoHashMap(u32, CompiledFunction).init(allocator),
            .target_arch = builtin.cpu.arch,
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.code_memory);
        self.function_counters.deinit();
        self.compiled_functions.deinit();
    }

    // Profile function execution and trigger compilation
    pub fn profileFunction(self: *Self, func_idx: u32) !bool {
        const result = try self.function_counters.getOrPut(func_idx);
        if (!result.found_existing) {
            result.value_ptr.* = 1;
            return false;
        } else {
            result.value_ptr.* += 1;
            return result.value_ptr.* >= self.compilation_threshold;
        }
    }

    // Compile a function to native code
    pub fn compileFunction(self: *Self, module: *Module, func_idx: u32) !CompiledFunction {
        if (self.compiled_functions.get(func_idx)) |cached| {
            return cached;
        }

        const func = &module.functions.items[func_idx];
        var codegen = CodeGen.init(self.allocator);
        defer codegen.deinit();

        // Generate function prologue
        try codegen.emitFunctionPrologue();

        // Compile function body
        try self.compileFunctionBody(&codegen, module, func.*);

        // Generate function epilogue
        try codegen.emitFunctionEpilogue();

        // Copy generated code to executable memory
        const code_size = codegen.buffer.items.len;
        if (self.code_offset + code_size > self.code_memory.len) {
            return error.OutOfCodeMemory;
        }

        @memcpy(self.code_memory[self.code_offset..self.code_offset + code_size], codegen.buffer.items);
        const entry_point: *const fn (*Runtime, []Value) Value = @ptrCast(@alignCast(self.code_memory[self.code_offset..].ptr));

        const compiled = CompiledFunction{
            .entry_point = entry_point,
            .code_size = code_size,
            .register_usage = RegisterMask{}, // TODO: Track actual usage
        };

        self.code_offset += code_size;
        try self.compiled_functions.put(func_idx, compiled);

        return compiled;
    }

    fn compileFunctionBody(_: *Self, codegen: *CodeGen, _: *Module, func: *const Module.Function) !void {
        var reader = Module.Reader.init(func.code);

        while (reader.pos < func.code.len) {
            const opcode = try reader.readByte();

            switch (opcode) {
                0x6A => { // i32.add
                    try compileI32Add(codegen);
                },
                0x6B => { // i32.sub
                    try compileI32Sub(codegen);
                },
                0x6C => { // i32.mul
                    try compileI32Mul(codegen);
                },
                0x41 => { // i32.const
                    const value = try reader.readSLEB32();
                    try compileI32Const(codegen, value);
                },
                0x20 => { // local.get
                    const local_idx = try reader.readLEB128();
                    try compileLocalGet(codegen, local_idx);
                },
                0x21 => { // local.set
                    const local_idx = try reader.readLEB128();
                    try compileLocalSet(codegen, local_idx);
                },
                0x04 => { // if
                    const block_type = try reader.readByte();
                    _ = block_type; // Ignore for now
                    try compileIf(codegen);
                },
                0x05 => { // else
                    try compileElse(codegen);
                },
                0x0B => { // end
                    try compileEnd(codegen);
                },
                0x02 => { // block
                    const block_type = try reader.readByte();
                    _ = block_type; // Ignore for now
                    try compileBlock(codegen);
                },
                0x03 => { // loop
                    const block_type = try reader.readByte();
                    _ = block_type; // Ignore for now
                    try compileLoop(codegen);
                },
                0x0C => { // br
                    const label_idx = try reader.readLEB128();
                    try compileBr(codegen, label_idx);
                },
                0x0D => { // br_if
                    const label_idx = try reader.readLEB128();
                    try compileBrIf(codegen, label_idx);
                },
                0x46 => { // i32.eqz
                    try compileI32Eqz(codegen);
                },
                0x47 => { // i32.eq
                    try compileI32Eq(codegen);
                },
                0x48 => { // i32.ne
                    try compileI32Ne(codegen);
                },
                0x49 => { // i32.lt_s
                    try compileI32LtS(codegen);
                },
                0x4A => { // i32.lt_u
                    try compileI32LtU(codegen);
                },
                0x4B => { // i32.gt_s
                    try compileI32GtS(codegen);
                },
                0x4C => { // i32.gt_u
                    try compileI32GtU(codegen);
                },
                0x4D => { // i32.le_s
                    try compileI32LeS(codegen);
                },
                0x4E => { // i32.le_u
                    try compileI32LeU(codegen);
                },
                0x4F => { // i32.ge_s
                    try compileI32GeS(codegen);
                },
                0x50 => { // i32.ge_u
                    try compileI32GeU(codegen);
                },
                0x10 => { // call
                    const func_idx = try reader.readLEB128();
                    try compileCall(codegen, func_idx);
                },
                0x0F => { // return
                    break;
                },
                else => {
                    // Fallback to interpretation for unimplemented opcodes
                    return error.UnsupportedOpcode;
                },
            }
        }
    }

    fn compileI32Add(codegen: *CodeGen) !void {
        // Pop two values from virtual stack and add them
        if (codegen.value_stack.items.len < 2) return error.StackUnderflow;

        const b_slot = codegen.value_stack.pop().?;
        const a_slot = codegen.value_stack.pop().?;

        // Constant folding optimization
        if (a_slot.location == .constant and b_slot.location == .constant) {
            const result = a_slot.location.constant + b_slot.location.constant;
            try codegen.value_stack.append(codegen.allocator, CodeGen.StackSlot{
                .type = .i32,
                .location = .{ .constant = result },
            });
            return;
        }

        const dst_reg = try codegen.allocateRegister(.i32);
        const src_reg = try codegen.allocateRegister(.i32);

        // Load operands into registers with optimization
        try codegen.emitOptimizedMov(.{ .register = dst_reg }, a_slot.location);
        try codegen.emitOptimizedMov(.{ .register = src_reg }, b_slot.location);

        // Perform addition
        try codegen.emitAdd(dst_reg, src_reg);

        // Push result
        try codegen.value_stack.append(codegen.allocator,CodeGen.StackSlot{
            .type = .i32,
            .location = .{ .register = dst_reg },
        });
    }

    fn compileI32Sub(codegen: *CodeGen) !void {
        if (codegen.value_stack.items.len < 2) return error.StackUnderflow;

        const b_slot = codegen.value_stack.pop().?;
        const a_slot = codegen.value_stack.pop().?;

        const dst_reg = try codegen.allocateRegister(.i32);
        const src_reg = try codegen.allocateRegister(.i32);

        try codegen.emitMov(.{ .register = dst_reg }, a_slot.location);
        try codegen.emitMov(.{ .register = src_reg }, b_slot.location);
        try codegen.emitSub(dst_reg, src_reg);

        try codegen.value_stack.append(codegen.allocator,CodeGen.StackSlot{
            .type = .i32,
            .location = .{ .register = dst_reg },
        });
    }

    fn compileI32Mul(codegen: *CodeGen) !void {
        if (codegen.value_stack.items.len < 2) return error.StackUnderflow;

        const b_slot = codegen.value_stack.pop().?;
        const a_slot = codegen.value_stack.pop().?;

        // x64 imul requires rax
        try codegen.emitMov(.{ .register = .rax }, a_slot.location);

        const src_reg = try codegen.allocateRegister(.i32);
        try codegen.emitMov(.{ .register = src_reg }, b_slot.location);
        try codegen.emitMul(src_reg);

        try codegen.value_stack.append(codegen.allocator,CodeGen.StackSlot{
            .type = .i32,
            .location = .{ .register = .rax },
        });
    }

    fn compileI32Const(codegen: *CodeGen, value: i32) !void {
        try codegen.value_stack.append(codegen.allocator,CodeGen.StackSlot{
            .type = .i32,
            .location = .{ .constant = value },
        });
    }

    fn compileLocalGet(codegen: *CodeGen, local_idx: usize) !void {
        // Local variables are stored at [rbp - (local_idx + 1) * 8]
        const offset = @as(i32, @intCast((local_idx + 1) * 8)) * -1;
        try codegen.value_stack.append(codegen.allocator,CodeGen.StackSlot{
            .type = .i32, // TODO: Get actual type
            .location = .{ .stack = offset },
        });
    }

    fn compileLocalSet(codegen: *CodeGen, local_idx: usize) !void {
        if (codegen.value_stack.items.len < 1) return error.StackUnderflow;

        const value_slot = codegen.value_stack.pop().?;
        const offset = @as(i32, @intCast((local_idx + 1) * 8)) * -1;

        try codegen.emitMov(.{ .stack = offset }, value_slot.location);
    }

    fn compileBlock(codegen: *CodeGen) !void {
        const start_label = codegen.emitLabel();
        try codegen.control_stack.append(codegen.allocator, CodeGen.ControlFrame{
            .kind = .block,
            .start_label = start_label,
            .end_label = null,
            .break_label = null,
            .stack_height = codegen.value_stack.items.len,
        });
    }

    fn compileLoop(codegen: *CodeGen) !void {
        const start_label = codegen.emitLabel();
        try codegen.control_stack.append(codegen.allocator, CodeGen.ControlFrame{
            .kind = .loop,
            .start_label = start_label,
            .end_label = null,
            .break_label = null,
            .stack_height = codegen.value_stack.items.len,
        });
    }

    fn compileIf(codegen: *CodeGen) !void {
        if (codegen.value_stack.items.len < 1) return error.StackUnderflow;

        const condition_slot = codegen.value_stack.pop().?;
        const condition_reg = try codegen.allocateRegister(.i32);

        try codegen.emitMov(.{ .register = condition_reg }, condition_slot.location);
        try codegen.emitCmp(condition_reg, condition_reg); // Test if zero

        const start_label = codegen.emitLabel();
        try codegen.emitJz(0); // Will be patched later

        try codegen.control_stack.append(codegen.allocator, CodeGen.ControlFrame{
            .kind = .if_block,
            .start_label = start_label,
            .end_label = start_label + 6, // Position after jz instruction
            .break_label = null,
            .stack_height = codegen.value_stack.items.len,
        });
    }

    fn compileElse(codegen: *CodeGen) !void {
        if (codegen.control_stack.items.len == 0) return error.ControlStackUnderflow;

        var frame = &codegen.control_stack.items[codegen.control_stack.items.len - 1];
        if (frame.kind != .if_block) return error.InvalidElse;

        // Jump over else block
        const jmp_pos = codegen.emitLabel();
        try codegen.emitJmp(0); // Will be patched later

        // Patch the if condition jump to point here
        if (frame.end_label) |end_pos| {
            const else_start = codegen.emitLabel();
            try codegen.patchJump(end_pos, else_start);
        }

        frame.break_label = jmp_pos + 5; // Position after jmp instruction
    }

    fn compileEnd(codegen: *CodeGen) !void {
        if (codegen.control_stack.items.len == 0) return error.ControlStackUnderflow;

        const frame = codegen.control_stack.pop().?;
        const end_label = codegen.emitLabel();

        // Patch any pending jumps
        if (frame.break_label) |break_pos| {
            try codegen.patchJump(break_pos, end_label);
        }

        if (frame.kind == .if_block and frame.end_label != null) {
            // Patch the original if condition if there was no else
            if (frame.break_label == null) {
                try codegen.patchJump(frame.end_label.?, end_label);
            }
        }
    }

    fn compileBr(codegen: *CodeGen, label_idx: usize) !void {
        if (label_idx >= codegen.control_stack.items.len) return error.InvalidLabel;

        const target_frame = &codegen.control_stack.items[codegen.control_stack.items.len - 1 - label_idx];

        if (target_frame.kind == .loop) {
            // Branch to loop start
            const current_pos = codegen.emitLabel();
            const offset = @as(i32, @intCast(target_frame.start_label)) - @as(i32, @intCast(current_pos)) - 5;
            try codegen.emitJmp(offset);
        } else {
            // Branch to block/if end (will be patched later)
            try codegen.emitJmp(0);
        }
    }

    fn compileBrIf(codegen: *CodeGen, label_idx: usize) !void {
        if (codegen.value_stack.items.len < 1) return error.StackUnderflow;
        if (label_idx >= codegen.control_stack.items.len) return error.InvalidLabel;

        const condition_slot = codegen.value_stack.pop().?;
        const condition_reg = try codegen.allocateRegister(.i32);

        try codegen.emitMov(.{ .register = condition_reg }, condition_slot.location);
        try codegen.emitCmp(condition_reg, condition_reg); // Test if zero

        const target_frame = &codegen.control_stack.items[codegen.control_stack.items.len - 1 - label_idx];

        if (target_frame.kind == .loop) {
            // Conditional branch to loop start
            const current_pos = codegen.emitLabel();
            const offset = @as(i32, @intCast(target_frame.start_label)) - @as(i32, @intCast(current_pos)) - 6;
            try codegen.emitJz(offset);
        } else {
            // Conditional branch to block/if end (will be patched later)
            try codegen.emitJz(0);
        }
    }

    fn compileI32Eqz(codegen: *CodeGen) !void {
        if (codegen.value_stack.items.len < 1) return error.StackUnderflow;

        const value_slot = codegen.value_stack.pop().?;
        const reg = try codegen.allocateRegister(.i32);

        try codegen.emitMov(.{ .register = reg }, value_slot.location);
        try codegen.emitCmp(reg, reg); // Test if zero
        try codegen.emitSetcc(0x94, reg); // setz

        try codegen.value_stack.append(codegen.allocator, CodeGen.StackSlot{
            .type = .i32,
            .location = .{ .register = reg },
        });
    }

    fn compileI32Eq(codegen: *CodeGen) !void {
        if (codegen.value_stack.items.len < 2) return error.StackUnderflow;

        const b_slot = codegen.value_stack.pop().?;
        const a_slot = codegen.value_stack.pop().?;

        const reg1 = try codegen.allocateRegister(.i32);
        const reg2 = try codegen.allocateRegister(.i32);

        try codegen.emitMov(.{ .register = reg1 }, a_slot.location);
        try codegen.emitMov(.{ .register = reg2 }, b_slot.location);
        try codegen.emitCmp(reg1, reg2);
        try codegen.emitSetcc(0x94, reg1); // setz

        try codegen.value_stack.append(codegen.allocator, CodeGen.StackSlot{
            .type = .i32,
            .location = .{ .register = reg1 },
        });
    }

    fn compileI32Ne(codegen: *CodeGen) !void {
        if (codegen.value_stack.items.len < 2) return error.StackUnderflow;

        const b_slot = codegen.value_stack.pop().?;
        const a_slot = codegen.value_stack.pop().?;

        const reg1 = try codegen.allocateRegister(.i32);
        const reg2 = try codegen.allocateRegister(.i32);

        try codegen.emitMov(.{ .register = reg1 }, a_slot.location);
        try codegen.emitMov(.{ .register = reg2 }, b_slot.location);
        try codegen.emitCmp(reg1, reg2);
        try codegen.emitSetcc(0x95, reg1); // setnz

        try codegen.value_stack.append(codegen.allocator, CodeGen.StackSlot{
            .type = .i32,
            .location = .{ .register = reg1 },
        });
    }

    fn compileI32LtS(codegen: *CodeGen) !void {
        if (codegen.value_stack.items.len < 2) return error.StackUnderflow;

        const b_slot = codegen.value_stack.pop().?;
        const a_slot = codegen.value_stack.pop().?;

        const reg1 = try codegen.allocateRegister(.i32);
        const reg2 = try codegen.allocateRegister(.i32);

        try codegen.emitMov(.{ .register = reg1 }, a_slot.location);
        try codegen.emitMov(.{ .register = reg2 }, b_slot.location);
        try codegen.emitCmp(reg1, reg2);
        try codegen.emitSetcc(0x9C, reg1); // setl

        try codegen.value_stack.append(codegen.allocator, CodeGen.StackSlot{
            .type = .i32,
            .location = .{ .register = reg1 },
        });
    }

    fn compileI32LtU(codegen: *CodeGen) !void {
        if (codegen.value_stack.items.len < 2) return error.StackUnderflow;

        const b_slot = codegen.value_stack.pop().?;
        const a_slot = codegen.value_stack.pop().?;

        const reg1 = try codegen.allocateRegister(.i32);
        const reg2 = try codegen.allocateRegister(.i32);

        try codegen.emitMov(.{ .register = reg1 }, a_slot.location);
        try codegen.emitMov(.{ .register = reg2 }, b_slot.location);
        try codegen.emitCmp(reg1, reg2);
        try codegen.emitSetcc(0x92, reg1); // setb

        try codegen.value_stack.append(codegen.allocator, CodeGen.StackSlot{
            .type = .i32,
            .location = .{ .register = reg1 },
        });
    }

    fn compileI32GtS(codegen: *CodeGen) !void {
        if (codegen.value_stack.items.len < 2) return error.StackUnderflow;

        const b_slot = codegen.value_stack.pop().?;
        const a_slot = codegen.value_stack.pop().?;

        const reg1 = try codegen.allocateRegister(.i32);
        const reg2 = try codegen.allocateRegister(.i32);

        try codegen.emitMov(.{ .register = reg1 }, a_slot.location);
        try codegen.emitMov(.{ .register = reg2 }, b_slot.location);
        try codegen.emitCmp(reg1, reg2);
        try codegen.emitSetcc(0x9F, reg1); // setg

        try codegen.value_stack.append(codegen.allocator, CodeGen.StackSlot{
            .type = .i32,
            .location = .{ .register = reg1 },
        });
    }

    fn compileI32GtU(codegen: *CodeGen) !void {
        if (codegen.value_stack.items.len < 2) return error.StackUnderflow;

        const b_slot = codegen.value_stack.pop().?;
        const a_slot = codegen.value_stack.pop().?;

        const reg1 = try codegen.allocateRegister(.i32);
        const reg2 = try codegen.allocateRegister(.i32);

        try codegen.emitMov(.{ .register = reg1 }, a_slot.location);
        try codegen.emitMov(.{ .register = reg2 }, b_slot.location);
        try codegen.emitCmp(reg1, reg2);
        try codegen.emitSetcc(0x97, reg1); // seta

        try codegen.value_stack.append(codegen.allocator, CodeGen.StackSlot{
            .type = .i32,
            .location = .{ .register = reg1 },
        });
    }

    fn compileI32LeS(codegen: *CodeGen) !void {
        if (codegen.value_stack.items.len < 2) return error.StackUnderflow;

        const b_slot = codegen.value_stack.pop().?;
        const a_slot = codegen.value_stack.pop().?;

        const reg1 = try codegen.allocateRegister(.i32);
        const reg2 = try codegen.allocateRegister(.i32);

        try codegen.emitMov(.{ .register = reg1 }, a_slot.location);
        try codegen.emitMov(.{ .register = reg2 }, b_slot.location);
        try codegen.emitCmp(reg1, reg2);
        try codegen.emitSetcc(0x9E, reg1); // setle

        try codegen.value_stack.append(codegen.allocator, CodeGen.StackSlot{
            .type = .i32,
            .location = .{ .register = reg1 },
        });
    }

    fn compileI32LeU(codegen: *CodeGen) !void {
        if (codegen.value_stack.items.len < 2) return error.StackUnderflow;

        const b_slot = codegen.value_stack.pop().?;
        const a_slot = codegen.value_stack.pop().?;

        const reg1 = try codegen.allocateRegister(.i32);
        const reg2 = try codegen.allocateRegister(.i32);

        try codegen.emitMov(.{ .register = reg1 }, a_slot.location);
        try codegen.emitMov(.{ .register = reg2 }, b_slot.location);
        try codegen.emitCmp(reg1, reg2);
        try codegen.emitSetcc(0x96, reg1); // setbe

        try codegen.value_stack.append(codegen.allocator, CodeGen.StackSlot{
            .type = .i32,
            .location = .{ .register = reg1 },
        });
    }

    fn compileI32GeS(codegen: *CodeGen) !void {
        if (codegen.value_stack.items.len < 2) return error.StackUnderflow;

        const b_slot = codegen.value_stack.pop().?;
        const a_slot = codegen.value_stack.pop().?;

        const reg1 = try codegen.allocateRegister(.i32);
        const reg2 = try codegen.allocateRegister(.i32);

        try codegen.emitMov(.{ .register = reg1 }, a_slot.location);
        try codegen.emitMov(.{ .register = reg2 }, b_slot.location);
        try codegen.emitCmp(reg1, reg2);
        try codegen.emitSetcc(0x9D, reg1); // setge

        try codegen.value_stack.append(codegen.allocator, CodeGen.StackSlot{
            .type = .i32,
            .location = .{ .register = reg1 },
        });
    }

    fn compileI32GeU(codegen: *CodeGen) !void {
        if (codegen.value_stack.items.len < 2) return error.StackUnderflow;

        const b_slot = codegen.value_stack.pop().?;
        const a_slot = codegen.value_stack.pop().?;

        const reg1 = try codegen.allocateRegister(.i32);
        const reg2 = try codegen.allocateRegister(.i32);

        try codegen.emitMov(.{ .register = reg1 }, a_slot.location);
        try codegen.emitMov(.{ .register = reg2 }, b_slot.location);
        try codegen.emitCmp(reg1, reg2);
        try codegen.emitSetcc(0x93, reg1); // setae

        try codegen.value_stack.append(codegen.allocator, CodeGen.StackSlot{
            .type = .i32,
            .location = .{ .register = reg1 },
        });
    }

    fn compileCall(_: *CodeGen, _: usize) !void {
        // Function calls are complex to implement in JIT, so for now we'll fall back
        // to interpretation for function calls. This requires runtime integration.
        return error.UnsupportedOpcode;
    }
};

// Import from runtime for JIT integration
const Runtime = @import("runtime.zig");