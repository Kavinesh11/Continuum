import 'package:flutter_test/flutter_test.dart';
import 'package:ui/models/user_model.dart';

void main() {
  group('UserModel', () {
    test('mock factory creates valid user', () {
      final user = UserModel.mock();

      expect(user.id, isNotEmpty);
      expect(user.fullName, isNotEmpty);
      expect(user.email, contains('@'));
      expect(user.platform, isNotEmpty);
      expect(user.zone, isNotEmpty);
    });

    test('constructor assigns all fields', () {
      final user = UserModel(
        id: 'ZOM-1234',
        fullName: 'Test Worker',
        email: 'test@example.com',
        platform: 'Zomato',
        zone: 'Mumbai - Andheri',
      );

      expect(user.id, 'ZOM-1234');
      expect(user.fullName, 'Test Worker');
      expect(user.email, 'test@example.com');
      expect(user.platform, 'Zomato');
      expect(user.zone, 'Mumbai - Andheri');
    });
  });
}
