import struct
from hwReg import readReg
import reg_defines_add_registers_nic as rd

y = []
for i in xrange(9):
    y.append(long(readReg(rd.HDR_LAST_HEADERS_SEEN_0_REG() + 4*i)))

l = rd.OF_HEADER_REG_WIDTH() / 32 + 1
print "length: ", l
s = struct.Struct((rd.OF_HEADER_REG_WIDTH() / 32 + 1) * 'L')
for i, v in enumerate(y):
    print i, " ", hex(v)
    print type(v)
print s.size
mydata = s.pack(*y)

c = struct.Struct('H'+'B' * 12+ 'H'+ 'B'+ 'H'+ 'B'+ 'B'+ 'I'+ 'I'+ 'H'+ 'H')
print c.format
for x in c.unpack(mydata):
    print hex(x)

