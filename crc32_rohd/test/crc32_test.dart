import 'dart:ffi';
import "dart:io";
import "dart:async";
import 'package:rohd/rohd.dart';
import 'package:test/test.dart';
import 'package:crc32/crc32.dart';
import 'package:rohd_vf/rohd_vf.dart';
import 'package:crc32/rohdplus.dart';
import 'package:logging/logging.dart';

class MemoryModel {
  // Create a sparse memory
  Map<int, int> memory = {};

  // Read from memory
  List<int> read(int addr, int length) {
    List<int> data = [];
    for (int i = 0; i < length; i++) {
      data.add(memory[addr + i] ?? 0);
    }
    return data;
  }

  // Write to memory
  void write(int addr, List<int> data) {
    for (int i = 0; i < data.length; i++) {
      memory[addr + i] = data[i];
      Logger.root.fine(
        "[MEM] Writing ${data[i].toRadixString(16)} to ${(addr + i).toRadixString(16)}",
      );
    }
  }

  void init() {
    for (int i = 0; i < 0x200000; i++) memory[i] = i & 0xff;
    Logger.root.info("[MEM] Initialized memory");
  }

  static int count = 0;

  void run(Logic clk, MemIO mem) {
    clk.posedge.listen((e) async {
      count += 1;
      while (mem.req.isRead.value == 0.L() && mem.req.valid.value == 1.L()) {
        write(
          mem.req.addr.value.toInt(),
          List<int>.generate(
            mem.req.sizeInBytes.value.toInt(),
            (i) => mem.req.data.value.slice(8 * i + 7, 8 * i).toInt(),
          ),
        );
        await clk.nextPosedge;
      }
    });

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

class TB {
  MemoryModel mem = MemoryModel();
  late final CoreIO io = CoreIO();
  late final Crc32 crc32_ = Crc32(io);
  TB() {
    io.clk <= SimpleClockGenerator(2).clk;
    crc32_.build();
  }

  run(Function test) async {
    mem.init();
    io.initProvider();
    io.mem.req.ready.inject(1);
    mem.run(io.clk, io.mem);
    await test();
  }
}

void main() async {
  TB tb = TB();

  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.time}: ${record.message}');
  });

  tearDown(() async {
    await Simulator.reset();
  });

  test('my first test', () async {
    WaveDumper w = WaveDumper(tb.crc32_);
    Simulator.setMaxSimTime(300);
    CoreIO io = tb.io;

    unawaited(Simulator.run());
    await tb.run(() async {
      await io.reset_sequence(5);
      await io.cmd.drive(io.clk, CommandTransaction(0x10000, 0x20000, 0x4));
      await io.busy.nextNegedge;
      await io.cmd.drive(io.clk, CommandTransaction(0x10000, 0x20000, 0x4));
      await io.busy.nextNegedge;
      await Simulator.simulationEnded;
    });

    print("Simulator time: ${Simulator.time}");
  });
}
