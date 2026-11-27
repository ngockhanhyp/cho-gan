import 'package:cho_gan/cloud_app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Free listings are recognized by price and legacy gift category', () {
    expect(listingIsGift({'category': 'Gia dụng', 'price': 0}), isTrue);
    expect(listingIsGift({'category': 'Cho tặng', 'price': 25000}), isTrue);
    expect(listingIsGift({'category': 'Gia dụng', 'price': 25000}), isFalse);
  });

  test('Legacy gift category displays as a neutral product category', () {
    expect(listingProductCategory({'category': 'Cho tặng'}), 'Đồ cũ');
    expect(listingProductCategory({'category': 'Gia dụng'}), 'Gia dụng');
  });
}
