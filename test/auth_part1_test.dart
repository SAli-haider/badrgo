import 'package:flutter_test/flutter_test.dart';
import 'package:badrgo_ops_console/features/auth/domain/entities/user_entity.dart';
import 'package:badrgo_ops_console/features/auth/data/models/user_model.dart';

void main() {
  group('Part 1.1: UserEntity Domain Logic', () {
    test('hasPermission evaluates strictly against permissions list', () {
      const user = UserEntity(
        id: 'usr-1',
        name: 'Doha Dispatcher',
        email: 'dispatch.doha@demo.test',
        role: 'dispatcher',
        city: 'Doha',
        permissions: ['trip:read', 'trip:assign', 'trip:cancel', 'driver:track'],
      );

      expect(user.hasPermission('trip:assign'), isTrue);
      expect(user.hasPermission('trip:cancel'), isTrue);
      expect(user.hasPermission('kpi:read'), isFalse);
      expect(user.hasPermission('user:manage'), isFalse);
    });

    test('canAccessCity checks jurisdiction correctly', () {
      const dohaUser = UserEntity(
        id: 'usr-2',
        name: 'Doha Ops',
        email: 'ops.doha@demo.test',
        role: 'ops_manager',
        city: 'Doha',
        permissions: ['kpi:read'],
      );

      const superAdmin = UserEntity(
        id: 'usr-3',
        name: 'Super Admin',
        email: 'superadmin@demo.test',
        role: 'super_admin',
        city: 'All cities',
        permissions: ['kpi:read', 'user:manage'],
      );

      expect(dohaUser.canAccessCity('Doha'), isTrue);
      expect(dohaUser.canAccessCity('Al Rayyan'), isFalse);
      expect(dohaUser.canAccessCity('Al Wakrah'), isFalse);

      expect(superAdmin.canAccessCity('Doha'), isTrue);
      expect(superAdmin.canAccessCity('Al Rayyan'), isTrue);
      expect(superAdmin.canAccessCity('Al Wakrah'), isTrue);
    });

    test('isViewer correctly flags phone masking requirement', () {
      const viewer = UserEntity(
        id: 'usr-4',
        name: 'Viewer',
        email: 'viewer.doha@demo.test',
        role: 'viewer',
        city: 'Doha',
        permissions: ['kpi:read', 'trip:read'],
      );

      const dispatcher = UserEntity(
        id: 'usr-5',
        name: 'Dispatcher',
        email: 'dispatch.doha@demo.test',
        role: 'dispatcher',
        city: 'Doha',
        permissions: ['trip:read'],
      );

      expect(viewer.isViewer, isTrue);
      expect(dispatcher.isViewer, isFalse);
    });
  });

  group('Part 1.1: UserModel DTO & JSON Mapping', () {
    test('Correctly maps backend JSON payload to UserEntity', () {
      final json = {
        'id': 'usr-100',
        'name': 'Doha Support',
        'email': 'support.doha@demo.test',
        'role': 'support',
        'city': 'Doha',
        'permissions': ['trip:read', 'trip:refund', 'alert:read'],
        'isBanned': false,
      };

      final model = UserModel.fromJson(json);
      final entity = model.toEntity();

      expect(entity.id, 'usr-100');
      expect(entity.name, 'Doha Support');
      expect(entity.email, 'support.doha@demo.test');
      expect(entity.role, 'support');
      expect(entity.city, 'Doha');
      expect(entity.permissions, ['trip:read', 'trip:refund', 'alert:read']);
      expect(entity.isBanned, isFalse);
    });

    test('Handles fallback when name is absent and defaults to email or Operator', () {
      final json = {
        'email': 'viewer.doha@demo.test',
        'role': 'viewer',
        'permissions': ['kpi:read'],
      };

      final model = UserModel.fromJson(json);
      expect(model.name, 'viewer.doha@demo.test');
      expect(model.city, 'Doha');
    });
  });
}
