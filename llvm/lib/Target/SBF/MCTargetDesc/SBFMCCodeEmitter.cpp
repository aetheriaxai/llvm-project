//===-- SBFMCCodeEmitter.cpp - Convert SBF code to machine code -----------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file implements the SBFMCCodeEmitter class.
//
//===----------------------------------------------------------------------===//

#include "MCTargetDesc/SBFMCTargetDesc.h"
#include "llvm/ADT/SmallVector.h"
#include "llvm/MC/MCCodeEmitter.h"
#include "llvm/MC/MCExpr.h"
#include "llvm/MC/MCFixup.h"
#include "llvm/MC/MCInst.h"
#include "llvm/MC/MCInstrInfo.h"
#include "llvm/MC/MCRegisterInfo.h"
#include "llvm/MC/MCSubtargetInfo.h"
#include "llvm/Support/Endian.h"
#include "llvm/Support/EndianStream.h"
#include <cassert>
#include <cstdint>

using namespace llvm;

#define DEBUG_TYPE "mccodeemitter"

namespace {

class SBFMCCodeEmitter : public MCCodeEmitter {
  const MCRegisterInfo &MRI;
  bool IsLittleEndian;

public:
  SBFMCCodeEmitter(const MCInstrInfo &, const MCRegisterInfo &mri,
                   bool IsLittleEndian)
      : MRI(mri), IsLittleEndian(IsLittleEndian) {}
  SBFMCCodeEmitter(const SBFMCCodeEmitter &) = delete;
  void operator=(const SBFMCCodeEmitter &) = delete;
  ~SBFMCCodeEmitter() override = default;

  // getBinaryCodeForInstr - TableGen'erated function for getting the
  // binary encoding for an instruction.
  uint64_t getBinaryCodeForInstr(const MCInst &MI,
                                 SmallVectorImpl<MCFixup> &Fixups,
                                 const MCSubtargetInfo &STI) const;

  // getMachineOpValue - Return binary encoding of operand. If the machin
  // operand requires relocation, record the relocation and return zero.
  unsigned getMachineOpValue(const MCInst &MI, const MCOperand &MO,
                             SmallVectorImpl<MCFixup> &Fixups,
                             const MCSubtargetInfo &STI) const;

  uint64_t getMemoryOpValue(const MCInst &MI, unsigned Op,
                            SmallVectorImpl<MCFixup> &Fixups,
                            const MCSubtargetInfo &STI) const;

  void encodeInstruction(const MCInst &MI, raw_ostream &OS,
                         SmallVectorImpl<MCFixup> &Fixups,
                         const MCSubtargetInfo &STI) const override;
};

} // end anonymous namespace

MCCodeEmitter *llvm::createSBFMCCodeEmitter(const MCInstrInfo &MCII,
                                            MCContext &Ctx) {
  return new SBFMCCodeEmitter(MCII, *Ctx.getRegisterInfo(), true);
}

MCCodeEmitter *llvm::createSBFbeMCCodeEmitter(const MCInstrInfo &MCII,
                                              MCContext &Ctx) {
  return new SBFMCCodeEmitter(MCII, *Ctx.getRegisterInfo(), false);
}

unsigned SBFMCCodeEmitter::getMachineOpValue(const MCInst &MI,
                                             const MCOperand &MO,
                                             SmallVectorImpl<MCFixup> &Fixups,
                                             const MCSubtargetInfo &STI) const {
  if (MO.isReg())
    return MRI.getEncodingValue(MO.getReg());
  if (MO.isImm())
    return static_cast<unsigned>(MO.getImm());

  assert(MO.isExpr());

  const MCExpr *Expr = MO.getExpr();

  assert(Expr->getKind() == MCExpr::SymbolRef);

  if (MI.getOpcode() == SBF::JAL)
    // func call name
    Fixups.push_back(MCFixup::create(0, Expr, FK_PCRel_4));
  else if (MI.getOpcode() == SBF::LD_imm64)
    Fixups.push_back(MCFixup::create(0, Expr, FK_SecRel_8));
  else
    // bb label
    Fixups.push_back(MCFixup::create(0, Expr, FK_PCRel_2));

  return 0;
}

static uint8_t SwapBits(uint8_t Val)
{
  return (Val & 0x0F) << 4 | (Val & 0xF0) >> 4;
}

void SBFMCCodeEmitter::encodeInstruction(const MCInst &MI, raw_ostream &OS,
                                         SmallVectorImpl<MCFixup> &Fixups,
                                         const MCSubtargetInfo &STI) const {
  unsigned Opcode = MI.getOpcode();
  support::endian::Writer OSE(OS,
                              IsLittleEndian ? support::little : support::big);

  if (Opcode == SBF::LD_imm64 || Opcode == SBF::LD_pseudo) {
    uint64_t Value = getBinaryCodeForInstr(MI, Fixups, STI);
    OS << char(Value >> 56);
    if (IsLittleEndian)
      OS << char((Value >> 48) & 0xff);
    else
      OS << char(SwapBits((Value >> 48) & 0xff));
    OSE.write<uint16_t>(0);
    OSE.write<uint32_t>(Value & 0xffffFFFF);

    const MCOperand &MO = MI.getOperand(1);
    uint64_t Imm = MO.isImm() ? MO.getImm() : 0;
    OSE.write<uint8_t>(0);
    OSE.write<uint8_t>(0);
    OSE.write<uint16_t>(0);
    OSE.write<uint32_t>(Imm >> 32);
  } else {
    // Get instruction encoding and emit it
    uint64_t Value = getBinaryCodeForInstr(MI, Fixups, STI);
    OS << char(Value >> 56);
    if (IsLittleEndian)
      OS << char((Value >> 48) & 0xff);
    else
      OS << char(SwapBits((Value >> 48) & 0xff));
    OSE.write<uint16_t>((Value >> 32) & 0xffff);
    OSE.write<uint32_t>(Value & 0xffffFFFF);
  }
}

// Encode SBF Memory Operand
uint64_t SBFMCCodeEmitter::getMemoryOpValue(const MCInst &MI, unsigned Op,
                                            SmallVectorImpl<MCFixup> &Fixups,
                                            const MCSubtargetInfo &STI) const {
  // For CMPXCHG instructions, output is implicitly in R0/W0,
  // so memory operand starts from operand 0.
  int MemOpStartIndex = 1, Opcode = MI.getOpcode();
  if (Opcode == SBF::CMPXCHGW32 || Opcode == SBF::CMPXCHGD)
    MemOpStartIndex = 0;

  uint64_t Encoding;
  const MCOperand Op1 = MI.getOperand(MemOpStartIndex);
  assert(Op1.isReg() && "First operand is not register.");
  Encoding = MRI.getEncodingValue(Op1.getReg());
  Encoding <<= 16;
  MCOperand Op2 = MI.getOperand(MemOpStartIndex + 1);
  assert(Op2.isImm() && "Second operand is not immediate.");
  Encoding |= Op2.getImm() & 0xffff;
  return Encoding;
}

#include "SBFGenMCCodeEmitter.inc"
