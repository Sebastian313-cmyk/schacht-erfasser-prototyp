import 'package:erfasser_app/services/validation_service.dart';
import 'package:erfasser_app/services/speicher_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

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

  group('ValidationService.validateSchachtdurchmesserCm', () {
    test('requires a value', () {
      expect(
        ValidationService.validateSchachtdurchmesserCm(''),
        'Bitte Schachtdurchmesser eintragen.',
      );
    });

    test('accepts standard ES diameters', () {
      expect(ValidationService.validateSchachtdurchmesserCm('100'), isNull);
      expect(ValidationService.validateSchachtdurchmesserCm('120'), isNull);
      expect(ValidationService.validateSchachtdurchmesserCm('100,0'), isNull);
    });

    test('rejects non-standard ES diameters', () {
      expect(
        ValidationService.validateSchachtdurchmesserCm('80'),
        'Schachtdurchmesser muss 100 oder 120 cm sein.',
      );
    });
  });

  group('ValidationService.validateUniquePosition', () {
    test('reserves both component positions of an Ablaufrinne', () async {
      const storageKey = 'obj_E100_Testweg_1/3_SSK';
      await SpeicherService.upsertEntry(storageKey, {
        'typ': 'SSK',
        'evnr': 'E100',
        'strasse': 'Testweg',
        'posNr': '1/3',
        'ablaufrinne': true,
      });

      final positionOne = await ValidationService.validateUniquePosition(
        evnr: 'E100',
        strasse: 'Testweg',
        posNr: '1',
      );
      final positionThree = await ValidationService.validateUniquePosition(
        evnr: 'E100',
        strasse: 'Testweg',
        posNr: '3',
      );
      final overlappingAblaufrinne =
          await ValidationService.validateUniquePosition(
            evnr: 'E100',
            strasse: 'Testweg',
            posNr: '3/5',
          );

      expect(positionOne.isValid, isFalse);
      expect(positionOne.message, contains('Position 1'));
      expect(positionThree.isValid, isFalse);
      expect(positionThree.message, contains('Position 3'));
      expect(overlappingAblaufrinne.isValid, isFalse);
      expect(overlappingAblaufrinne.message, contains('Position 3'));
    });

    test(
      'allows editing the existing Ablaufrinne without self-conflict',
      () async {
        const storageKey = 'obj_E101_Testweg_1/3_SSK';
        await SpeicherService.upsertEntry(storageKey, {
          'typ': 'SSK',
          'evnr': 'E101',
          'strasse': 'Testweg',
          'posNr': '1/3',
          'ablaufrinne': true,
        });

        final result = await ValidationService.validateUniquePosition(
          evnr: 'E101',
          strasse: 'Testweg',
          posNr: '1/3',
          excludeStorageKey: storageKey,
        );

        expect(result.isValid, isTrue);
      },
    );

    test('blocks an Ablaufrinne when a component is already used', () async {
      await SpeicherService.upsertEntry('obj_E102_Testweg_3_ES', {
        'typ': 'ES',
        'evnr': 'E102',
        'strasse': 'Testweg',
        'posNr': '3',
      });

      final result = await ValidationService.validateUniquePosition(
        evnr: 'E102',
        strasse: 'Testweg',
        posNr: '1/3',
      );

      expect(result.isValid, isFalse);
      expect(result.message, contains('Position 3'));
    });
  });
}
