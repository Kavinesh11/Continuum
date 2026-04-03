// DriverProvider — InheritedWidget that makes the active sandbox driver
// available to any widget in the tree without prop-drilling.

import 'package:flutter/material.dart';
import 'sandbox_drivers.dart';
import 'sandbox_service.dart';

class DriverProvider extends InheritedWidget {
  final SandboxDriver driver;
  final SandboxService service;
  final void Function(SandboxDriver) switchDriver;

  const DriverProvider({
    Key? key,
    required this.driver,
    required this.service,
    required this.switchDriver,
    required Widget child,
  }) : super(key: key, child: child);

  static DriverProvider of(BuildContext context) {
    final result = context.dependOnInheritedWidgetOfExactType<DriverProvider>();
    assert(result != null, 'No DriverProvider found in widget tree');
    return result!;
  }

  @override
  bool updateShouldNotify(DriverProvider old) => driver != old.driver;
}

/// Root widget that owns the active driver state
class DriverProviderRoot extends StatefulWidget {
  final Widget child;

  const DriverProviderRoot({Key? key, required this.child}) : super(key: key);

  @override
  State<DriverProviderRoot> createState() => _DriverProviderRootState();
}

class _DriverProviderRootState extends State<DriverProviderRoot> {
  SandboxDriver _activeDriver = allSandboxDrivers.first;

  void _switchDriver(SandboxDriver driver) {
    setState(() => _activeDriver = driver);
  }

  @override
  Widget build(BuildContext context) {
    return DriverProvider(
      driver: _activeDriver,
      service: SandboxService(_activeDriver),
      switchDriver: _switchDriver,
      child: widget.child,
    );
  }
}
