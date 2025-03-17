import "dart:async";
import 'package:rohd/rohd.dart';
import 'package:crc32/crc32.dart';
import 'package:test/test.dart';
import 'package:crc32/rohdplus.dart';
import 'testbench.dart';
import 'package:logging/logging.dart';

void main() async {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.time}: ${record.message}');
  });

  tearDown(() async {
    await Simulator.reset();
  });

  test('my first test', () async {
    TB tb = TB();
    await tb.build();
    WaveDumper w = WaveDumper(tb.crc32_);
    Simulator.setMaxSimTime(300);

    unawaited(Simulator.run());
    await tb.run(() async {
      await tb.io.reset_sequence(5);
      await tb.io.cmd.drive(
        tb.io.clk,
        CommandTransaction(0x10001, 0x20000, 0x2),
      );
      await tb.io.busy.nextNegedge;
      try {
        expect(tb.mem.readDword(0x20000), 0x9242ccb6);
      } catch (e) {
        Simulator.endSimulation();
        rethrow;
      }
      Simulator.endSimulation();
    });
  });

  test('my second test', () async {
    TB tb = TB();
    await tb.build();
    WaveDumper w = WaveDumper(tb.crc32_);
    Simulator.setMaxSimTime(30000);
    CoreIO io = tb.io;

    unawaited(Simulator.run());
    await tb.run(() async {
      await io.reset_sequence(5);
      await io.cmd.drive(io.clk, CommandTransaction(0x10000, 0x20000, 0x4));
      await io.busy.nextNegedge;
      await io.cmd.drive(io.clk, CommandTransaction(0x10000, 0x20000, 0x4));
      await io.busy.nextNegedge;
      Simulator.endSimulation();
    });
  });
}
