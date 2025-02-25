import "rohdplus.dart";
import "interfaces.dart";
import "crcTable.dart";

enum Crc32State { IDLE, READ, WRITE, RESP }

class Crc32 extends Module {
  late final CoreIO io;

  Crc32(CoreIO inio) {
    // Define logic here, including state transitions and memory handling
    io = CoreIO.clone(inio)..pairConnectIO(this, inio, PairRole.consumer);

    rtl();
  }

  // Add logic
  void rtl() {
    Logic srcAddr = Logic(name: 'srcAddr', width: 64);
    Logic dstAddr = Logic(name: 'dstAddr', width: 64);
    Logic len = Logic(name: 'len', width: 64);
    Logic crc32Val = Logic(name: 'crc32Val', width: 32);
    Logic srcAddr_f = Logic(name: 'srcAddr_f', width: 64);
    Logic dstAddr_f = Logic(name: 'dstAddr_f', width: 64);
    Logic len_f = Logic(name: 'len_f', width: 64);
    Logic crc32Val_f = Logic(name: 'crc32Val_f', width: 32);
    Logic crc32ValNext = Logic(name: 'crc32ValNext', width: 32);

    srcAddr_f <= flop(io.clk, srcAddr, reset: io.reset, resetValue: 0.C(64));
    dstAddr_f <= flop(io.clk, dstAddr, reset: io.reset, resetValue: 0.C(64));
    len_f <= flop(io.clk, len, reset: io.reset, resetValue: 0.C(64));
    crc32Val_f <= flop(io.clk, crc32Val, reset: io.reset, resetValue: 0.C(32));

    final defaults = [
      len < len_f,
      dstAddr < dstAddr_f,
      srcAddr < srcAddr_f,
      crc32Val < crc32Val_f,
      io.mem.req.valid < 0.C(),
      io.mem.req.isRead < 0.C(),
      io.mem.req.data < Const(LogicValue.z, width: 32),
    ];

    List<State<Crc32State>> crc32States = [
      State(
        Crc32State.IDLE,
        events: {io.cmd.valid & io.cmd.rs1.neq(0.C(64)): Crc32State.READ},
        actions:
            defaults +
            [
              If(
                io.cmd.valid,
                then: [
                  If(
                    io.cmd.rs1.neq(0.C(64)),
                    then: [srcAddr < io.cmd.rs1, dstAddr < io.cmd.rs2],
                    orElse: [len < io.cmd.rs2],
                  ),
                ],
              ),
            ],
      ),
      State(
        Crc32State.READ,
        events: {len_f.eq(1.C(64)): Crc32State.WRITE},
        actions:
            defaults +
            [
              io.mem.req.valid < io.mem.req.ready,
              io.mem.req.isRead < 1.C(),
              io.mem.req.addr < srcAddr_f,
              io.mem.req.sizeInBytes < 1.L(64),
              srcAddr < srcAddr_f + 1.C(64),
              crc32Val < crc32Val_f ^ crc32ValNext,
              If(
                len_f.eq(1.C(64)),
                then: [len < 4.C(64)],
                orElse: [len < len_f - 1],
              ),
            ],
      ),
      State(
        Crc32State.WRITE,
        events: {io.mem.req.valid & io.mem.req.ready: Crc32State.RESP},
        actions:
            defaults +
            [
              io.mem.req.valid < 1.C(),
              io.mem.req.data < crc32Val_f ^ 0xFFFFFFFF.C(32),
              len < len_f - 1.C(64),
              dstAddr < dstAddr_f + 1.C(64),
              io.mem.req.addr < dstAddr_f,
              io.mem.req.sizeInBytes < 4.C(64),
            ],
      ),
      State(
        Crc32State.RESP,
        events: {1.C(): Crc32State.IDLE},
        actions:
            defaults +
            [
              io.resp.valid < 1.C(),
              io.resp.data < crc32Val_f ^ 0xFFFFFFFF.C(32),
              len < 0.C(64),
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

    nLookupIndex <= ((crc32Val_f.slice(7, 0) ^ (io.mem.resp.data.slice(7, 0))));

    Combinational([
      Case(nLookupIndex, [
        for (int i = 0; i < table.length; i++)
          CaseItem(i.C(8), [crc32ValNext < Const(table[i], width: 32)]),
      ]),
    ]);
  }
}
