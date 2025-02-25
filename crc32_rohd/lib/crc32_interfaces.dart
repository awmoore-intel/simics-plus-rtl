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
  Logic get rs1 => port('rs1');
  Logic get rs2 => port('rs2');

  Command()
    : super(
        portsFromProvider: [Port('valid'), Port('rs1', 64), Port('rs2', 64)],
      );

  @override
  init() {
    valid.inject(0);
    rs1.inject(0);
    rs2.inject(0);
  }

  drive(Logic clk, CommandTransaction t) async {
    //await clk.nextPosedge;
    valid.inject(1);
    rs1.inject(0);
    rs2.inject(t.len);
    await clk.nextPosedge;
    rs1.inject(t.srcAddr);
    rs2.inject(t.dstAddr);
    await clk.nextPosedge;
    valid.inject(0);
  }
}

class Response extends MyPairInterface {
  Logic get valid => port('valid');
  Logic get data => port('data');

  Response() : super(portsFromConsumer: [Port('valid'), Port('data', 32)]);
}

class MemReq extends MyPairInterface {
  Logic get valid => port('valid');
  Logic get isRead => port('is_read');
  Logic get sizeInBytes => port('size_in_bytes');
  Logic get addr => port('addr');
  Logic get data => port('data');
  Logic get ready => port('ready');
  MemReq()
    : super(
        portsFromConsumer: [
          Port('valid'),
          Port('is_read'),
          Port('size_in_bytes', 64),
          Port('addr', 64),
          Port('data', 32),
        ],
        portsFromProvider: [Port('ready')],
      );

  @override
  init() {
    valid.inject(0);
    isRead.inject(0);
    sizeInBytes.inject(0);
    addr.inject(0);
    data.inject(0);
    ready.inject(0);
  }
}

class MemResp extends MyPairInterface {
  Logic get valid => port('valid');
  Logic get data => port('data');
  MemResp() : super(portsFromProvider: [Port('valid'), Port('data', 64)]) {}
}

class MemIO extends MyPairInterface {
  MemReq get req => super.sub('req');
  MemResp get resp => super.sub('resp');
  MemIO() {
    addSubInterface("req", MemReq());
    addSubInterface("resp", MemResp());
  }

  init() {}
}

class CoreIO extends MyPairInterface {
  Logic get clk => port('clk');
  Logic get reset => port('reset');
  Logic get busy => port('busy');

  Command get cmd => super.sub('cmd');
  Response get resp => super.sub('resp');
  MemIO get mem => super.sub('mem');

  CoreIO()
    : super(
        portsFromConsumer: [Port('busy')],
        portsFromProvider: [Port('clk'), Port('reset')],
      ) {
    addSubInterface("cmd", Command());
    addSubInterface("mem", MemIO());
    addSubInterface("resp", Response());
  }

  CoreIO.clone(CoreIO otherInterface) : this();

  reset_sequence([int duration = 1]) async {
    reset.inject(1);
    for (int i = 0; i < duration; i++) {
      await clk.nextPosedge;
    }
    reset.inject(0);
  }

  init() {
    clk.inject(0);
    reset.inject(0);
    busy.inject(0);
    cmd.init();
    resp.init();
    mem.init();
    mem.init();
  }
}
