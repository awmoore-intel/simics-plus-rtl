import 'dart:mirrors';
import 'dart:async';
import 'dart:io';

import 'package:rohd/rohd.dart';
import 'package:crc32/crc32.dart';
export 'package:crc32/interfaces.dart';
import 'package:rohd_vf/rohd_vf.dart';

void main() async {
  CoreIO io = CoreIO();
  var crc32_ = Crc32(io);
  await crc32_.build();

  String verilog = crc32_.generateSynth();
  var file = File('crc32.sv');
  file.writeAsStringSync(verilog);
}
