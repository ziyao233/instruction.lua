local io			= require "io";
local os			= require "os";

local instruction		= require "instruction";

instruction.defaults["arch"] = "riscv32i";

local list = instruction.InstrList();
list:append("lui", 2, 0x1000);
list:append("auipc", 3, 0x1000);
list:append("jal", 4, 4);
list:append("jal", 4, -4);
list:append("jalr", 1, 2, 4);
list:append("jalr", 1, 2, -4);
list:append("beq", 1, 0, 4);
list:append("beq", 1, 0, -4);
list:append("lb", 1, 31, 4);
list:append("lb", 1, 31, -4);
list:append("lb", 1, 31, 0x400);
list:append("sb", 1, 31, 4);
list:append("sh", 1, 31, -4);
list:append("sw", 1, 31, 0x400);
list:append("addi", 1, 31, 4);
list:append("slti", 1, 31, 4);
list:append("xori", 1, 31, -4);
list:append("slli", 1, 31, 4);
list:append("srli", 1, 31, 31);
list:append("srai", 1, 31, 4);
list:append("srai", 1, 31, 31);
list:append("add", 1, 30, 31);
list:append("sub", 31, 30, 2);
list:append("srl", 30, 31, 31);
list:append("sra", 2, 31, 4);
print(list);
io.open("test.S", "w"):write(".text\n.global _start\n_start:\n" .. tostring(list)):close();
local result = list:encode();
io.open("test.1.bin", "w"):write(result);
os.execute("clang --target=riscv32-unknown-elf test.S -o test " ..
	   "-O0 -nostdlib");
os.execute("objcopy test test.2.bin -O binary -j .text");
local asBin = io.open("test.2.bin", "rb"):read('a');
assert(asBin == result);
