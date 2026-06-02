import 'package:erfasser_app/services/validation_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ValidationService.validatePositionField', () {
    test('rejects empty value with default message', () {
      expect(ValidationService.validatePositionField('   '), 'Pflichtfeld');
    });

    test('rejects invalid format', () {
      expect(
        ValidationService.validatePositionField('1/2'),
        'Format: Zahl + optionaler Buchstabe',
      );
    });

    test('accepts valid positions', () {
      expect(ValidationService.validatePositionField('12'), isNull);
      expect(ValidationService.validatePositionField('12a'), isNull);
      expect(ValidationService.validatePositionField('7B'), isNull);
    });

    test('supports custom required message', () {
      expect(
        ValidationService.validatePositionField(
          '',
          requiredMessage: 'Pflichtfeld für Ablaufrinne',
        ),
        'Pflichtfeld für Ablaufrinne',
      );
    });
  });
}