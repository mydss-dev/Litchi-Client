import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/shared/models/api_models.dart';
import 'package:litchi_client/shared/models/model_mappers.dart';

void main() {
  test('plan mapping preserves all HTML paragraph and list entries', () {
    final raw = [
      '<p>第一项 &amp; 第二项</p>',
      '<ul>',
      for (var i = 1; i <= 8; i++) '<li>权益 $i</li>',
      '</ul>',
    ].join();
    final plan = ModelMappers.toPlan(RemotePlan(
      id: 1,
      name: 'Test Plan',
      description: raw,
      transferEnable: 128,
      monthPrice: 2800,
      show: 1,
    ));

    expect(plan.features.length, 9);
    expect(plan.features.first, '第一项 & 第二项');
    expect(plan.features.last, '权益 8');
  });
}
