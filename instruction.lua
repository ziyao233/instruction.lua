-- SDPX-License-Identifier: MPL-2.0
--[[
--	instruction.lua
--	Copyright (c) 2025 Yao Zi. All rights reserved.
--]]

local string		= require "string";
local table		= require "table";

local function le32b(n)
	return string.pack("<I4", n);
end

local function
genmask(high, low)
	return ((1 << (high - low + 1)) - 1) << low;
end

local function
bfield(high, low, n)
	local mask = genmask(high - low, 0);
	return (n & mask) << low;
end

local function
bget(high, low, n)
	return (n & genmask(high, low)) >> low;
end

local function
BType(opcode, funct3, rs1, rs2, imm)
	local offset = bfield(7, 7,	bget(11, 11, imm))	|
		       bfield(11, 8,	bget(4, 1, imm))	|
		       bfield(30, 25,	bget(10, 5, imm))	|
		       bfield(31, 31,	bget(12, 12, imm));
	return le32b(bfield(6, 0,	opcode)			|
		     bfield(14, 12,	funct3)			|
		     bfield(19, 15,	rs1)			|
		     bfield(24, 20,	rs2)			|
		     offset);
end

local function
IType(opcode, func3, rd, rs1, imm)
	return le32b(bfield(6, 0, opcode)	|
		     bfield(14, 12, func3)	|
		     bfield(11, 7, rd)		|
		     bfield(19, 15, rs1)	|
		     bfield(31, 20, imm));
end

local function
UType(opcode, rd, imm)
	return le32b(bfield(6, 0, opcode)	|
		     bfield(11, 7, rd)		|
		     bfield(31, 12, imm));
end

-- What the hell
local function
JType(opcode, rd, imm)
	local offset = bfield(19, 12, bget(19, 12, imm))	|
		       bfield(20, 20, bget(11, 11, imm))	|
		       bfield(30, 21, bget(10, 1,  imm))	|
		       bfield(31, 31, bget(20, 20, imm));

	return le32b(bfield(6, 0, opcode)	|
		     bfield(11, 7, rd)		|
		     offset);
end

local function
SType(opcode, funct3, rs1, rs2, imm)
	return le32b(bfield(6, 0,	opcode)			|
		     bfield(11, 7,	bget(4, 0, imm))	|
		     bfield(14, 12,	funct3)			|
		     bfield(19, 15,	rs1)			|
		     bfield(24, 20,	rs2)			|
		     bfield(31,	25,	bget(11, 5, imm)));
end

local function
RType(opcode, funct3, funct7, rd, rs1, rs2)
	return le32b(bfield(6, 0,	opcode)			|
		     bfield(11, 7,	rd)			|
		     bfield(14, 12,	funct3)			|
		     bfield(19, 15,	rs1)			|
		     bfield(24, 20,	rs2)			|
		     bfield(31, 25,	funct7));
end

local function
condbr(funct3)
	return function(_, rs1, rs2, imm)
		return BType(0x63, funct3, rs1, rs2, imm);
	end;
end

local function
loadmem(funct3)
	return function(_, rd, rs1, imm)
		return IType(0x3, funct3, rd, rs1, imm);
	end;
end

local function
storemem(funct3)
	return function(_, src, base, imm)
		return SType(0x23, funct3, base, src, imm);
	end;
end

local function
immarith(funct3)
	return function(_, rs1, rs2, imm)
		return IType(0x13, funct3, rs1, rs2, imm);
	end;
end

local function
regarith(funct3, funct7)
	return function(_, rd, rs1, rs2)
		return RType(0x33, funct3, funct7, rd, rs1, rs2);
	end;
end

local riscv32iEncoders = {
	["lui"]		= function(_, rd, imm)
				return UType(0x37, rd, imm);
			  end,
	["auipc"]	= function(_, rd, imm)
				return UType(0x17, rd, imm);
			  end,
	["jal"]		= function(_, rd, imm)
				return JType(0x6f, rd, imm);
			  end,
	["jalr"]	= function(_, rd, rs, imm)
				return IType(0x67, 0x0, rd, rs, imm);
			  end,
	["beq"]		= condbr(0),
	["bne"]		= condbr(1),
	["blt"]		= condbr(4),
	["bge"]		= condbr(5),
	["bltu"]	= condbr(6),
	["bgeu"]	= condbr(7),
	["lb"]		= loadmem(0),
	["lh"]		= loadmem(1),
	["lw"]		= loadmem(2),
	["lbu"]		= loadmem(3),
	["lhu"]		= loadmem(4),
	["sb"]		= storemem(0),
	["sh"]		= storemem(1),
	["sw"]		= storemem(2),
	["addi"]	= immarith(0),
	["slti"]	= immarith(2),
	["sltiu"]	= immarith(3),
	["xori"]	= immarith(4),
	["ori"]		= immarith(6),
	["andi"]	= immarith(7),
	["slli"]	= function(_, rd, rs1, shamt)
				return IType(0x13, 0x1, rd, rs1, shamt & 0x1f);
			  end,
	["srli"]	= function(_, rd, rs1, shamt)
				return IType(0x13, 0x5, rd, rs1, shamt & 0x1f);
			  end,
	["srai"]	= function(_, rd, rs1, shamt)
				shamt = (shamt & 0x1f) | (1 << 10);
				return IType(0x13, 0x5, rd, rs1, shamt);
			  end,
	["add"]		= regarith(0, 0x0),
	["sub"]		= regarith(0, 0x20),
	["sll"]		= regarith(1, 0x0),
	["slt"]		= regarith(2, 0x0),
	["sltu"]	= regarith(3, 0x0),
	["xor"]		= regarith(4, 0x0),
	["srl"]		= regarith(5, 0x0),
	["sra"]		= regarith(5, 0x20),
	["or"]		= regarith(6, 0x0),
	["and"]		= regarith(7, 0x0),
};

local function
printer1R1I(op, dst, imm)
	return ("\t%s\tx%d, 0x%x"):format(op, dst, imm);
end

local function
printer2R1I(op, dst, src, imm)
	return ("\t%s\tx%d, x%d, 0x%x"):format(op, dst, src, imm);
end

local function
printer2R1Off(op, dst, src, imm)
	return ("\t%s\tx%d, 0x%x(x%d)"):format(op, dst, imm, src);
end

local function
printerCondBranch(op, src1, src2, imm)
	return ("\t%s\tx%d, x%d, . + (0x%x)"):format(op, src1, src2, imm);
end

local function
printer3R(op, dst, src1, src2)
	return ("\t%s\tx%d, x%d, x%d"):format(op, dst, src1, src2);
end

local riscv32iPrinters = {
	["lui"]		= printer1R1I,
	["auipc"]	= printer1R1I,
	["jal"]		= printer1R1I,
	["jalr"]	= printer2R1Off,
	["beq"]		= printerCondBranch,
	["bne"]		= printerCondBranch,
	["blt"]		= printerCondBranch,
	["bge"]		= printerCondBranch,
	["bltu"]	= printerCondBranch,
	["bgeu"]	= printerCondBranch,
	["lb"]		= printer2R1Off,
	["lh"]		= printer2R1Off,
	["lw"]		= printer2R1Off,
	["lbu"]		= printer2R1Off,
	["lhu"]		= printer2R1Off,
	["sb"]		= printer2R1Off,
	["sh"]		= printer2R1Off,
	["sw"]		= printer2R1Off,
	["addi"]	= printer2R1I,
	["slti"]	= printer2R1I,
	["sltiu"]	= printer2R1I,
	["xori"]	= printer2R1I,
	["ori"]		= printer2R1I,
	["andi"]	= printer2R1I,
	["slli"]	= printer2R1I,
	["srli"]	= printer2R1I,
	["srai"]	= printer2R1I,
	["add"]		= printer3R,
	["sub"]		= printer3R,
	["sll"]		= printer3R,
	["slt"]		= printer3R,
	["sltu"]	= printer3R,
	["xor"]		= printer3R,
	["srl"]		= printer3R,
	["sra"]		= printer3R,
	["or"]		= printer3R,
	["and"]		= printer3R,
};

local archDefs = {
	["riscv32i"] = {
			printers = riscv32iPrinters,
			encoders = riscv32iEncoders
		       },
};

local defaults = {
	arch = "",
};

local instrListMeta = {};
instrListMeta.__index = instrListMeta;

local function
iterator(self, index)
	if self.length == index then
		return nil;
	end

	index = index + 1;

	return index, self.ops[index], self.dst[index],
		      self.src1[index], self.src2[index];
end

instrListMeta.ipairs = function(self)
	return iterator, self, 0, nil;
end

instrListMeta.encode = function(self)
	local encoders = self.def.encoders;
	local buf = {};

	for index, op, dst, src1, src2 in self:ipairs() do
		local fn = encoders[op];
		if not fn then
			error(("Invalid opcode: %s"):format(op));
		end

		buf[index] = fn(op, dst, src1, src2);
	end

	return table.concat(buf);
end;

instrListMeta.__tostring = function(self)
	local printers = self.def.printers;
	local buf = {};

	for index, op, dst, src1, src2 in self:ipairs() do
		local fn = printers[op];
		if not fn then
			error(("Invalid opcode: %s"):format(op));
		end

		buf[index] = fn(op, dst, src1, src2);
	end

	return table.concat(buf, '\n');
end;

instrListMeta.append = function(self, op, dst, src1, src2)
	local i = self.length + 1;

	self.ops[i]	= op;
	self.dst[i]	= dst or false;
	self.src1[i]	= src1 or false;
	self.src2[i]	= src2 or false;

	self.length = i;
end;

local function
InstrList(arch)
	arch = arch or defaults.arch;

	local list = {
			def	= archDefs[arch],
			length	= 0,
			ops	= {},
			dst	= {},
			src1	= {},
			src2	= {},
		     };
	if not list.def then
		error(("Invalid architecture %s"):format(arch));
	end

	return setmetatable(list, instrListMeta);
end

return {
	defaults	= defaults,
	InstrList	= InstrList,
       };
