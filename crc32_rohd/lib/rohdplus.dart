import 'package:rohd/rohd.dart';
export 'package:rohd/rohd.dart';

// Add .C() and .L() to int
extension ConstInt on int {
  Const C([width = 1]) => Const(this, width: width, fill: false);
  LogicValue L([width = 1]) => LogicValue.ofInt(this, width);
}

extension InitPairInterface on PairInterface {
  void initProvider([int value = 0]) {
    for (Logic p in getPorts({PairDirection.fromProvider}).values) {
      p.inject(value);
    }
    for (var s in subInterfaces.values) {
      s.initProvider();
    }
  }

  void initConsumer([int value = 0]) {
    for (Logic p in getPorts({PairDirection.fromConsumer}).values) {
      p.inject(value);
    }
    for (var s in subInterfaces.values) {
      s.initConsumer();
    }
  }
}

class MyPairInterface extends PairInterface {
  // Enable subclasses to define ports using these functions
  portsFromProvider() => <Logic>[];
  portsFromConsumer() => <Logic>[];
  sharedInputPorts() => <Logic>[];
  commonInOutPorts() => <Logic>[];

  MyPairInterface({
    super.portsFromConsumer,
    super.portsFromProvider,
    super.sharedInputPorts,
    super.commonInOutPorts,
  }) {
    setPorts(portsFromProvider(), [PairDirection.fromProvider]);
    setPorts(portsFromConsumer(), [PairDirection.fromConsumer]);
    setPorts(sharedInputPorts(), [PairDirection.sharedInputs]);
    setPorts(commonInOutPorts(), [PairDirection.commonInOuts]);
  }

  @override
  PairInterfaceType addSubInterface<PairInterfaceType extends PairInterface>(
    String name,
    PairInterfaceType subInterface, {
    bool reverse = false,
  }) {
    // Fixup name
    subInterface.modify = (n) => '${name}_$n';
    return super.addSubInterface(name, subInterface, reverse: reverse);
  }

  dynamic sub(String name) {
    return super.subInterfaces[name];
  }
}
