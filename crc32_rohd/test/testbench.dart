import 'package:rohd/rohd.dart';
import 'package:crc32/crc32.dart';
import 'package:logging/logging.dart';
import 'package:crc32/rohdplus.dart';

class MemoryModel {
  // Create a sparse memory
  Map<int, int> memory = {};

  int readDword(int addr) {
    return read(addr, 4).fold(0, (prev, element) => prev << 8 | element);
  }

  // Read from memory
  List<int> read(int addr, int length) {
    List<int> data = [];
    for (int i = 0; i < length; i++) {
      data.add(memory[addr + i] ?? 0);
      Logger.root.fine(
        "[MEM] Reading ${memory[addr + i]!.toRadixString(16)} from ${(addr + i).toRadixString(16)}",
      );
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
    // BFM is always ready

    mem.req.ready.inject(1);
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
        mem.resp.data.inject(read(mem.req.addr.value.toInt(), 1)[0]);

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
  }

  build() async {
    await crc32_.build();
  }

  run(Function test) async {
    mem.init();
    io.initProvider();
    mem.run(io.clk, io.mem);
    await test();
  }
}
