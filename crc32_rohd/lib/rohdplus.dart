import 'dart:ffi';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
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
    List<Logic>? portsFromConsumer,
    List<Logic>? portsFromProvider,
    List<Logic>? sharedInputPorts,
    List<Logic>? commonInOutPorts,
  }) : super(
         portsFromConsumer: portsFromConsumer,
         portsFromProvider: portsFromProvider,
         sharedInputPorts: sharedInputPorts,
         commonInOutPorts: commonInOutPorts,
       ) {
    setPorts(this.portsFromProvider(), [PairDirection.fromProvider]);
    setPorts(this.portsFromConsumer(), [PairDirection.fromConsumer]);
    setPorts(this.sharedInputPorts(), [PairDirection.sharedInputs]);
    setPorts(this.commonInOutPorts(), [PairDirection.commonInOuts]);
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
