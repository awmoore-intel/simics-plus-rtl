import "dart:io";
import "dart:async";
import 'package:rohd/rohd.dart';
import 'package:test/test.dart';
import 'package:crc32/crc32.dart';
import 'package:rohd_vf/rohd_vf.dart';
import 'package:crc32/rohdplus.dart';

extension MemoryModelTxn on MemoryModel {
  void init() {
    for (int i = 0; i < 0x200000; i++) memory[i] = i & 0xff;
  }

  static int count = 0;

  void listen_for_writes(Logic clk, MemIO mem) {
    clk.posedge.listen((e) async {
      count += 1;
      while (mem.req.isRead.value == 0.L() && mem.req.valid.value == 1.L()) {
        for (int i = 0; i < mem.req.sizeInBytes.value.toInt(); i++) {
          var val = mem.req.data.value.slice(8 * i + 7, 8 * i).toInt();
          memory[mem.req.addr.value.toInt() + i] = val;
          print("Writing ${val} to ${mem.req.addr.value.toInt() + i}");
        }
        await clk.nextPosedge;
      }
    });
  }

  void listen_for_reads(Logic clk, MemIO mem) {
    mem.resp.valid.inject(0);
    mem.resp.data.inject(LogicValue.z);
    clk.posedge.listen((e) async {
      count += 1;
      while (mem.req.isRead.value == 1.L() && mem.req.valid.value == 1.L()) {
        mem.resp.valid.inject(1);
        mem.resp.data.inject(memory[mem.req.addr.value.toInt()]);

        await clk.nextPosedge;
      }
      mem.resp.valid.inject(0);
      mem.resp.data.inject(LogicValue.z);
    });
  }
}

void main() async {
  CoreIO io = CoreIO();
  var crc32_ = Crc32(io);
  await crc32_.build();

  tearDown(() async {
    await Simulator.reset();
  });

  test('my first test', () async {
    WaveDumper w = WaveDumper(crc32_);
    Simulator.setMaxSimTime(30);
    io.clk <= SimpleClockGenerator(2).clk;
    MemoryModel mem = MemoryModel();

    mem.init();
    mem.listen_for_reads(io.clk, io.mem);
    mem.listen_for_writes(io.clk, io.mem);

    unawaited(Simulator.run());
    print("test");
    io.init();
    io.mem.req.ready.inject(1);
    await io.reset_sequence(5);
    await io.cmd.drive(io.clk, CommandTransaction(0x10000, 0x20000, 0x4));
    await io.busy.nextNegedge;
    await Simulator.simulationEnded;
    print("Simulator time: ${Simulator.time}");
  });
}
