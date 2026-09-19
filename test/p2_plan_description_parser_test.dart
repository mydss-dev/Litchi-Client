import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/shared/models/api_models.dart';
import 'package:litchi_client/shared/models/model_mappers.dart';
import 'package:litchi_client/shared/models/plan_description_parser.dart';

void main() {
  test('retains paragraph and nested inline text in independent rows', () {
    expect(
      PlanDescriptionParser.parse(
        '<p>高速 <strong>专线</strong> &amp; 稳定</p>'
        '<p>全球<br />节点</p><div>不限速</div>',
      ),
      ['高速 专线 & 稳定', '全球', '节点', '不限速'],
    );
  });

  test('retains unordered and ordered lists and complete descriptions', () {
    const remote = RemotePlan(
      id: 11,
      name: '完整套餐',
      description: '<ul><li>第一条</li><li>第二条</li></ul>'
          '<ol><li>第三条</li><li>第四条</li></ol>'
          '<p>第五条</p><p>第六条</p>',
      transferEnable: 1024,
      monthPrice: 1280,
      show: 1,
    );
    expect(ModelMappers.toPlan(remote).features, [
      '• 第一条', '• 第二条', '1. 第三条', '2. 第四条', '第五条', '第六条',
    ]);
  });

  test('decodes decimal, hex and common named entities', () {
    expect(
      PlanDescriptionParser.parse(
        '<p>价格&nbsp;¥&#49;&#x32;&mdash;支持&nbsp;&lt;HD&gt;'
        '&quot;高速&quot;&apos;测试&apos;&hellip;</p>',
      ),
      ['价格 ¥12—支持 <HD>"高速"\'测试\'…'],
    );
  });

  test('never executes markup or exposes script/style content', () {
    expect(
      PlanDescriptionParser.parse(
        '<p>安全</p><script>alert("secret")</script>'
        '<style>.secret {display:none}</style><!-- hidden -->'
        '<p>内容</p>',
      ),
      ['安全', '内容'],
    );
  });

  test('keeps plain text, escaped comparisons and unknown entities', () {
    expect(
      PlanDescriptionParser.parse('速率 &lt; 1Gbps\n额度&#x1F680; &custom;'),
      ['速率 < 1Gbps', '额度🚀 &custom;'],
    );
    expect(PlanDescriptionParser.parse(''), isEmpty);
  });

  test('keeps invalid code points as source text', () {
    expect(PlanDescriptionParser.parse('A&#xD800;B&#99999999;C'), [
      'A&#xD800;B&#99999999;C',
    ]);
  });
}
