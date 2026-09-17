import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/shared/models/api_models.dart';
import 'package:litchi_client/shared/models/app_models.dart';
import 'package:litchi_client/shared/models/model_mappers.dart';

void main() {
  test('HTML list and paragraph descriptions are retained, not capped at six', () {
    final plan = ModelMappers.toPlan(const RemotePlan(
      id: 1,
      name: 'Litchi Ultra',
      transferEnable: 512,
      show: 1,
      monthPrice: 1280,
      description: '<p>套餐介绍</p><ul><li>一</li><li>二</li><li>三</li>'
          '<li>四</li><li>五</li><li>六</li><li>七</li></ul>',
    ));
    expect(plan.category, PlanCategory.recurring);
    expect(plan.features, [
      '套餐介绍', '一', '二', '三', '四', '五', '六', '七',
    ]);
  });

  test('a priced data pack remains purchasable and has its own category', () {
    final plan = ModelMappers.toPlan(const RemotePlan(
      id: 2,
      name: '追加流量包',
      transferEnable: 100,
      onetimePrice: 2000,
      show: 1,
    ));
    expect(plan.category, PlanCategory.dataPack);
    expect(plan.oneTimePrice, 20);
    expect(plan.soldOut, isFalse);
  });

  test('disabled pricing alone does not mislabel a plan as a data pack', () {
    final plan = ModelMappers.toPlan(const RemotePlan(
      id: 3,
      name: '暂停售卖',
      transferEnable: 0,
      show: 1,
    ));
    expect(plan.category, PlanCategory.oneTime);
    expect(plan.oneTimePrice, isNull);
  });
}
