import 'package:flutter/material.dart';
import 'app.dart';
import 'core/di/app_dependencies.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize all core clients, repositories, and ViewModels via DI container
  final dependencies = await AppDependencies.init();

  runApp(BadrgoOpsApp(dependencies: dependencies));
}
