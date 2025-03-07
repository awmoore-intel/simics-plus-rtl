import 'package:rohd/rohd.dart';
import "rohdplus.dart";

class CommandTransaction {
  final int srcAddr;
  final int dstAddr;
  final int len;
  CommandTransaction(this.srcAddr, this.dstAddr, this.len);
}

class Command extends MyPairInterface {
  Logic get valid => port('valid');
  Logic get rs1 => port('bits_rs1');
  Logic get rs2 => port('bits_rs2');

  Command()
    : super(
        portsFromProvider: [
          Port('valid'),
          Port('bits_rs1', 64),
          Port('bits_rs2', 64),
        ],
      );

  drive(Logic clk, CommandTransaction t) async {
    await clk.nextPosedge;
    valid.inject(1);
    rs1.inject(t.srcAddr);
    rs2.inject(t.dstAddr);
    await clk.nextPosedge;
    valid.inject(0);
    await clk.nextPosedge;
    valid.inject(1);
    rs1.inject(0);
    rs2.inject(t.len);
    await clk.nextPosedge;
    valid.inject(0);
    rs1.inject(LogicValue.x);
    rs2.inject(LogicValue.x);
  }

  Stream<CommandTransaction> monitor(Logic clk) async* {
    while (true) {
      int len = 0;
      await clk.nextPosedge;
      if (valid.value.toBool() == true) {
        print("Valid is true");
        if (rs1.value.toInt() == 0) {
          len = rs2.value.toInt();
        } else {
          yield CommandTransaction(rs1.value.toInt(), rs2.value.toInt(), len);
        }
      }
    }
  }
}

class Response extends MyPairInterface {
  Logic get valid => port('valid');
  Logic get data => port('bits_data');

  Response() : super(portsFromConsumer: [Port('valid'), Port('bits_data', 64)]);
}

class MemReq extends MyPairInterface {
  Logic get valid => port('valid');
  Logic get isRead => port('bits_is_read');
  Logic get sizeInBytes => port('bits_size_in_bytes');
  Logic get addr => port('bits_addr');
  Logic get data => port('bits_data');
  Logic get ready => port('ready');
  MemReq()
    : super(
        portsFromConsumer: [
          Port('valid'),
          Port('bits_is_read'),
          Port('bits_size_in_bytes', 4),
          Port('bits_addr', 64),
          Port('bits_data', 64),
        ],
        portsFromProvider: [Port('ready')],
      );
}

class MemResp extends MyPairInterface {
  Logic get valid => port('valid');
  Logic get data => port('bits_data');
  MemResp() : super(portsFromProvider: [Port('valid'), Port('bits_data', 64)]);
}

class MemIO extends MyPairInterface {
  MemReq get req => super.sub('req');
  MemResp get resp => super.sub('resp');
  MemIO() {
    addSubInterface("req", MemReq());
    addSubInterface("resp", MemResp());
  }
}

class CoreIO extends MyPairInterface {
  Logic get clk => port('clock');
  Logic get reset => port('reset');
  Logic get busy => port('io_busy');

  Command get cmd => super.sub('io_cmd');
  Response get resp => super.sub('io_resp');
  MemIO get mem => super.sub('io_mem');

  CoreIO()
    : super(
        portsFromConsumer: [Port('io_busy')],
        portsFromProvider: [Port('clock'), Port('reset')],
      ) {
    addSubInterface("io_cmd", Command());
    addSubInterface("io_mem", MemIO());
    addSubInterface("io_resp", Response());
  }

  CoreIO.clone(CoreIO otherInterface) : this();

  reset_sequence([int duration = 1]) async {
    reset.inject(1);
    for (int i = 0; i < duration; i++) {
      await clk.nextPosedge;
    }
    reset.inject(0);
  }
}
