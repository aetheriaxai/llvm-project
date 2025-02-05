# RUN: llvm-mc -triple sbf --mcpu=sbfv2 -filetype=obj -o %t %s
# RUN: llvm-objdump --output-asm-variant=1 -d -r %t | FileCheck %s
# RUN: llvm-objdump --output-asm-variant=1 --mattr=+alu32 -d -r %t | FileCheck %s

.syntax_old

// ======== BPF_ALU Class ========
  w1 = -w1    // BPF_NEG
  w0 += w1    // BPF_ADD  | BPF_X
  w1 -= w2    // BPF_SUB  | BPF_X
  w2 *= w3    // BPF_MUL  | BPF_X
  w3 /= w4    // BPF_DIV  | BPF_X
// CHECK: 84 01 00 00 00 00 00 00      w1 = -w1
// CHECK: 0c 10 00 00 00 00 00 00      w0 += w1
// CHECK: 1c 21 00 00 00 00 00 00      w1 -= w2
// CHECK: 2c 32 00 00 00 00 00 00      w2 *= w3
// CHECK: 3c 43 00 00 00 00 00 00      w3 /= w4

  w4 |= w5    // BPF_OR   | BPF_X
  w5 &= w6    // BPF_AND  | BPF_X
  w6 <<= w7   // BPF_LSH  | BPF_X
  w7 >>= w8   // BPF_RSH  | BPF_X
  w8 ^= w9    // BPF_XOR  | BPF_X
  w9 = w10    // BPF_MOV  | BPF_X
  w10 s>>= w0 // BPF_ARSH | BPF_X
// CHECK: 4c 54 00 00 00 00 00 00      w4 |= w5
// CHECK: 5c 65 00 00 00 00 00 00      w5 &= w6
// CHECK: 6c 76 00 00 00 00 00 00      w6 <<= w7
// CHECK: 7c 87 00 00 00 00 00 00      w7 >>= w8
// CHECK: ac 98 00 00 00 00 00 00      w8 ^= w9
// CHECK: bc a9 00 00 00 00 00 00      w9 = w10
// CHECK: cc 0a 00 00 00 00 00 00      w10 s>>= w0

  w0 += 1           // BPF_ADD  | BPF_K
  w1 -= 0x1         // BPF_SUB  | BPF_K
  w2 *= -4          // BPF_MUL  | BPF_K
  w3 /= 5           // BPF_DIV  | BPF_K
// CHECK: 04 00 00 00 01 00 00 00      w0 += 0x1
// CHECK: 14 01 00 00 01 00 00 00      w1 -= 0x1
// CHECK: 24 02 00 00 fc ff ff ff      w2 *= -0x4
// CHECK: 34 03 00 00 05 00 00 00      w3 /= 0x5

  w4 |= 0xff        // BPF_OR   | BPF_K
  w5 &= 0xFF        // BPF_AND  | BPF_K
  w6 <<= 63         // BPF_LSH  | BPF_K
  w7 >>= 32         // BPF_RSH  | BPF_K
  w8 ^= 0           // BPF_XOR  | BPF_K
  w9 = 1            // BPF_MOV  | BPF_K
  w9 = 0xffffffff   // BPF_MOV  | BPF_K
  w10 s>>= 64       // BPF_ARSH | BPF_K
// CHECK: 44 04 00 00 ff 00 00 00      w4 |= 0xff
// CHECK: 54 05 00 00 ff 00 00 00      w5 &= 0xff
// CHECK: 64 06 00 00 3f 00 00 00      w6 <<= 0x3f
// CHECK: 74 07 00 00 20 00 00 00      w7 >>= 0x20
// CHECK: a4 08 00 00 00 00 00 00      w8 ^= 0x0
// CHECK: b4 09 00 00 01 00 00 00      w9 = 0x1
// CHECK: b4 09 00 00 ff ff ff ff      w9 = -0x1
// CHECK: c4 0a 00 00 40 00 00 00      w10 s>>= 0x40

  if w0 == w1 goto Llabel0   // BPF_JEQ  | BPF_X
  if w3 != w4 goto Llabel0   // BPF_JNE  | BPF_X
// CHECK: 1e 10 0b 00 00 00 00 00 	if w0 == w1 goto +0xb
// CHECK: 5e 43 0a 00 00 00 00 00 	if w3 != w4 goto +0xa

  if w1 > w2 goto Llabel0    // BPF_JGT  | BPF_X
  if w2 >= w3 goto Llabel0   // BPF_JGE  | BPF_X
  if w4 s> w5 goto Llabel0   // BPF_JSGT | BPF_X
  if w5 s>= w6 goto Llabel0  // BPF_JSGE | BPF_X
// CHECK: 2e 21 09 00 00 00 00 00 	if w1 > w2 goto +0x9
// CHECK: 3e 32 08 00 00 00 00 00 	if w2 >= w3 goto +0x8
// CHECK: 6e 54 07 00 00 00 00 00 	if w4 s> w5 goto +0x7
// CHECK: 7e 65 06 00 00 00 00 00 	if w5 s>= w6 goto +0x6

  if w6 < w7 goto Llabel0    // BPF_JLT  | BPF_X
  if w7 <= w8 goto Llabel0   // BPF_JLE  | BPF_X
  if w8 s< w9 goto Llabel0   // BPF_JSLT | BPF_X
  if w9 s<= w10 goto Llabel0 // BPF_JSLE | BPF_X
// CHECK: ae 76 05 00 00 00 00 00 	if w6 < w7 goto +0x5
// CHECK: be 87 04 00 00 00 00 00 	if w7 <= w8 goto +0x4
// CHECK: ce 98 03 00 00 00 00 00 	if w8 s< w9 goto +0x3
// CHECK: de a9 02 00 00 00 00 00 	if w9 s<= w10 goto +0x2

  if w0 == 0 goto Llabel0           // BPF_JEQ  | BPF_K
  if w3 != -1 goto Llabel0          // BPF_JNE  | BPF_K
// CHECK: 16 00 01 00 00 00 00 00 	if w0 == 0x0 goto +0x1
// CHECK: 56 03 00 00 ff ff ff ff 	if w3 != -0x1 goto +0x0

Llabel0 :
  if w1 > 64 goto Llabel0           // BPF_JGT  | BPF_K
  if w2 >= 0xffffffff goto Llabel0  // BPF_JGE  | BPF_K
  if w4 s> 0xffffffff goto Llabel0  // BPF_JSGT | BPF_K
  if w5 s>= 0x7fffffff goto Llabel0 // BPF_JSGE | BPF_K
// CHECK: 26 01 ff ff 40 00 00 00 	if w1 > 0x40 goto -0x1
// CHECK: 36 02 fe ff ff ff ff ff 	if w2 >= -0x1 goto -0x2
// CHECK: 66 04 fd ff ff ff ff ff 	if w4 s> -0x1 goto -0x3
// CHECK: 76 05 fc ff ff ff ff 7f 	if w5 s>= 0x7fffffff goto -0x4

  if w6 < 0xff goto Llabel0         // BPF_JLT  | BPF_K
  if w7 <= 0xffff goto Llabel0      // BPF_JLE  | BPF_K
  if w8 s< 0 goto Llabel0           // BPF_JSLT | BPF_K
  if w9 s<= -1 goto Llabel0         // BPF_JSLE | BPF_K
// CHECK: a6 06 fb ff ff 00 00 00 	if w6 < 0xff goto -0x5
// CHECK: b6 07 fa ff ff ff 00 00 	if w7 <= 0xffff goto -0x6
// CHECK: c6 08 f9 ff 00 00 00 00 	if w8 s< 0x0 goto -0x7
// CHECK: d6 09 f8 ff ff ff ff ff 	if w9 s<= -0x1 goto -0x8
