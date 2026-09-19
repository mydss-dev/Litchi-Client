import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/shared/models/api_models.dart';
import 'package:litchi_client/shared/models/model_mappers.dart';
import 'package:litchi_client/shared/services/plan_description_parser.dart';

void main() {
  test('preserves block, list and table content while dropping active markup', () {
    const raw = '<style>.x{display:none}</style>'
        '<script>alert(1)</script>'
        '<p>Fast&nbsp;network &amp; support</p>'
        '<ul><li>Hong&nbsp;Kong</li><li>Japan &#x1F1EF;&#x1F1F5;</li></ul>'
        '<table><tr><td>Devices</td><td>5</td></tr>'
        '<tr><td>Note</td><td>Tom&apos;s plan &#35;1</td></tr></table>';

    final features = PlanDescriptionParser.toFeatures(raw);

    expect(features, [
      'Fast network & support',
      '• Hong Kong',
      '• Japan 🇯🇵',
      'Devices · 5',
      "Note · Tom's plan #1",
    ]);
    expect(features.join(' '), isNot(contains('alert')));
    expect(features.join(' '), isNot(contains('display:none')));
  });

  test('mapper uses the shared parser for backend plan descriptions', () {
    const remote = RemotePlan(
      id: 22,
      name: 'Parser plan',
      description: '<p>A &amp; B</p><table><tr><td>C</td><td>D</td></tr></table>',
      transferEnable: 512,
      monthPrice: 1280,
      show: 1,
    );

    final plan = ModelMappers.toPlan(remote);

    expect(plan.features, ['A & B', 'C · D']);
  });

  test('invalid numeric entities are preserved instead of throwing', () {
    expect(
      PlanDescriptionParser.toFeatures('<p>x &#x110000; y &#xD800;</p>'),
      ['x &#x110000; y &#xD800;'],
    );
  });
}
