import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/di/app_dependencies.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/domain/repositories/auth_repository.dart';
import 'features/auth/presentation/bloc/auth_cubit.dart';
import 'features/dashboard/domain/repositories/dashboard_repository.dart';
import 'features/health/domain/repositories/health_repository.dart';
import 'features/health/presentation/bloc/health_cubit.dart';
import 'features/trips/domain/repositories/trips_repository.dart';

/// Root Application Widget.
class BadrgoOpsApp extends StatelessWidget {
  final AppDependencies dependencies;

  const BadrgoOpsApp({
    super.key,
    required this.dependencies,
  });

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AuthRepository>.value(value: dependencies.authRepository),
        RepositoryProvider<HealthRepository>.value(value: dependencies.healthRepository),
        RepositoryProvider<DashboardRepository>.value(value: dependencies.dashboardRepository),
        RepositoryProvider<TripsRepository>.value(value: dependencies.tripsRepository),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthCubit>.value(value: dependencies.authCubit),
          BlocProvider<HealthCubit>.value(value: dependencies.healthCubit),
        ],
        child: MaterialApp.router(
          title: 'badrgo Ops Console — Clean MVVM',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.darkTheme,
          routerConfig: dependencies.appRouter.router,
        ),
      ),
    );
  }
}
