import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/shared/models/api_models.dart';
import 'package:litchi_client/shared/models/model_mappers.dart';

void main() {
  test('plan descriptions keep all HTML paragraph and list items', () {
    const description = '<p>第一条</p><p>第二条</p>'
        '<ul><li>第三条</li><li>第四条</li></ul>'
        '<p>第五条</p><p>第六条</p><p>第七条</p>';
    const remote = RemotePlan(
      id: 10,
      name: '测试套餐',
      description: description,
      transferEnable: 512,
      monthPrice: 1280,
      show: 1,
    );
    final plan = ModelMappers.toPlan(remote);
    expect(plan.features, hasLength(7));
    expect(plan.features.first, '第一条');
    expect(plan.features[1], '第二条');
    expect(plan.features[2], '• 第三条');
    expect(plan.features.last, '第七条');
  });
}
