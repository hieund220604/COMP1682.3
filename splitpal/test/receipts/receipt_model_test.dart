import 'package:flutter_test/flutter_test.dart';
import 'package:splitpal/models/receipt.dart';

void main() {
  test('Receipt fromJson/to fields', () {
    final json = {
      '_id': 'r1',
      'imageUrl': 'http://example.com/img.jpg',
      'note': 'Lunch',
      'receiptDate': '2026-03-29T00:00:00.000Z',
      'tags': [
        {'_id': 't1', 'name': 'Food', 'color': 'red'}
      ],
      'createdAt': '2026-03-29T01:00:00.000Z',
    };

    final model = Receipt.fromJson(json);
    expect(model.id, 'r1');
    expect(model.imageUrl, contains('img.jpg'));
    expect(model.note, 'Lunch');
    expect(model.tags.first, isA<ReceiptTag>());
    expect(model.tags.first.name, 'Food');
  });

  test('Receipt parses tagIds fallback', () {
    final json = {
      '_id': 'r2',
      'imageUrl': 'http://example.com/img2.jpg',
      'tagIds': ['t1', 't2'],
      'receiptDate': '2026-03-29T00:00:00.000Z',
      'createdAt': '2026-03-29T01:00:00.000Z',
    };

    final model = Receipt.fromJson(json);
    expect(model.tags.length, 2);
    expect(model.tags.first.id, 't1');
    expect(model.tags.first.name, 't1');
  });
}
