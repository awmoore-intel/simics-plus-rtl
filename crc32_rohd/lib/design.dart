import "dart:ffi";

import "package:collection/collection.dart";
import "package:rohd/rohd.dart" as rohd;
import "package:rohd_hcl/rohd_hcl.dart" as rohd_hcl;
import "rohdplus.dart";
import "interfaces.dart";
import "crcTable.dart";
import "dart:mirrors";

enum Crc32State { IDLE, READ, WRITE, RESP }

extension Ext on Logic {
  Logic operator ^(int other) {
    print("EXT");
    return Xor2Gate(this, other.C(width)).out;
  }
}

class Crc32 extends Module {
  late final CoreIO io;

  Crc32(CoreIO inio) {
    // Define logic here, including state transitions and memory handling
    io = CoreIO.clone(inio)..pairConnectIO(this, inio, PairRole.consumer);

    _rtl();
  }

  // Add logic
  void _rtl() {
    Logic srcAddr = Logic(name: 'srcAddr', width: 64);
    Logic dstAddr = Logic(name: 'dstAddr', width: 64);
    Logic len = Logic(name: 'len', width: 64);
    Logic crc32Val = Logic(name: 'crc32Val', width: 32);
    Logic crc32ValNext = Logic(name: 'crc32ValNext', width: 32);

    Logic srcAddr_f = flop(io.clk, srcAddr, reset: io.reset, resetValue: 0);
    Logic dstAddr_f = flop(io.clk, dstAddr, reset: io.reset, resetValue: 0);
    Logic len_f = flop(io.clk, len, reset: io.reset, resetValue: 0);
    Logic crc32Val_f = flop(
      io.clk,
      crc32Val,
      reset: io.reset,
      resetValue: 0xffffffff,
    );

    final defaults = [
      len < len_f,
      dstAddr < dstAddr_f,
      srcAddr < srcAddr_f,
      crc32Val < crc32Val_f,
      io.mem.req.valid < 0,
      io.mem.req.isRead < 0,
      io.mem.req.addr < LogicValue.x,
      io.mem.req.sizeInBytes < 0,
      io.mem.req.data < Const(LogicValue.z, width: 64),
      io.resp.valid < 0,
      io.resp.data < Const(LogicValue.z, width: 64),
    ];

    List<State<Crc32State>> crc32States = [
      State(
        Crc32State.IDLE,
        events: {
          io.cmd.valid & io.cmd.rs1.neq(0): Crc32State.RESP,
          io.cmd.valid & io.cmd.rs1.eq(0): Crc32State.READ,
        },
        actions:
            defaults +
            [
              crc32Val < 0xffffffff,
              If(
                io.cmd.valid,
                then: [
                  If(
                    io.cmd.rs1.neq(0),
                    then: [srcAddr < io.cmd.rs1, dstAddr < io.cmd.rs2],
                    orElse: [len < io.cmd.rs2],
                  ),
                ],
              ),
            ],
      ),
      State(
        Crc32State.READ,
        events: {len_f.eq(1): Crc32State.WRITE},
        actions:
            defaults +
            [
              io.mem.req.valid < io.mem.req.ready,
              io.mem.req.isRead < 1,
              io.mem.req.addr < srcAddr_f,
              io.mem.req.sizeInBytes < 1,
              If(
                io.mem.req.valid & io.mem.req.ready,
                then: [
                  srcAddr < srcAddr_f + 1.L(64),
                  crc32Val < crc32ValNext,
                  If(len_f.eq(1), then: [len < 4], orElse: [len < len_f - 1]),
                ],
              ),
            ],
      ),
      State(
        Crc32State.WRITE,
        events: {io.mem.req.valid & io.mem.req.ready: Crc32State.RESP},
        actions:
            defaults +
            [
              io.mem.req.valid < 1,
              //io.mem.req.data.slice(31, 0) < crc32Val_f ^ 0xFFFFFFFF.C(32),// does not compile
              io.mem.req.data < crc32Val_f.zeroExtend(64) ^ 0xFFFFFFFF.C(64),
              len < len_f - 1,
              io.mem.req.addr < dstAddr_f,
              io.mem.req.sizeInBytes < 4,
            ],
      ),
      State(
        Crc32State.RESP,
        events: {1.C(): Crc32State.IDLE},
        actions:
            defaults +
            [
              io.resp.valid < 1,
              io.resp.data < (crc32Val_f.zeroExtend(64) ^ 0xFFFFFFFF.C(64)),
              len < 0,
            ],
      ),
    ];

    var fsm = FiniteStateMachine<Crc32State>(
      io.clk,
      io.reset,
      Crc32State.IDLE,
      crc32States,
    );

    io.busy <= fsm.currentState.neq(Crc32State.IDLE.index);

    Logic nLookupIndex = Logic(name: 'nLookupIndex', width: 8);
    Logic tableLookup = Logic(name: 'tableLookup', width: 32);

    List<Logic> table_ = [for (var c in table) Const(c, width: 32)];
    nLookupIndex <= ((crc32Val_f.slice(7, 0) ^ (io.mem.resp.data.slice(7, 0))));
    tableLookup <= nLookupIndex.selectFrom(table_);
    crc32ValNext <= (tableLookup ^ (crc32Val_f >>> 8));
  }
}
