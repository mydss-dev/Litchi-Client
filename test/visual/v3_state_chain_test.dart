import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/app/app_controller.dart';
import 'package:litchi_client/shared/models/api_models.dart';
import 'package:litchi_client/shared/models/app_models.dart';
import 'package:litchi_client/shared/services/api_client.dart';
import 'package:litchi_client/shared/services/panel_api.dart';
import 'package:litchi_client/v3/pages/v3_nodes_page.dart';
import 'package:litchi_client/v3/pages/v3_orders_page.dart';
import 'package:litchi_client/v3/pages/v3_shop_page.dart';
import 'package:litchi_client/v3/pages/v3_tickets_page.dart';
import 'package:litchi_client/v3/theme/v3_palette.dart';
import 'package:litchi_client/v3/ui/v3_components.dart';
import 'package:litchi_client/v3/ui/v3_empty_state.dart';
import 'package:litchi_client/v3/ui/v3_node_picker.dart';

import 'v3_visual_fixture.dart';

/// Round-3 audit N11: the shared three-state chain (loading skeleton ->
/// loaded -> named failure with a retry) was only ever pinned to its loaded
/// branch. These tests open each surface on the other two states through the
/// fixture's overridable knobs and watch the retry actually reach the
/// controller.
class _EmptyPlansController extends VisualV3Controller {
  _EmptyPlansController(
    super.page, {
    super.initialLoading,
    super.loadError,
  });

  // The shop judges its failure state on the unfiltered catalog, so the
  // error branch needs an empty one; the skeleton branch never reads it.
  @override
  List<PlanModel> get plans => const [];
}

// Same for the node surfaces: their error branch is judged on an empty fleet.
class _EmptyNodesController extends VisualV3Controller {
  _EmptyNodesController(super.page, {super.loadError});

  @override
  List<NodeModel> get nodes => const [];
}

/// A fake ledger whose failure and pacing the test drives directly; the
/// orders page owns its three-state chain locally through [PanelApi].
class _OrdersApi extends PanelApi {
  _OrdersApi() : super(ApiClient());

  int fetchCalls = 0;
  bool fail = false;
  Completer<List<RemoteOrder>>? gate;

  static const _orders = <RemoteOrder>[
    RemoteOrder(
      tradeNo: 'L202609160001',
      planName: 'Litchi Ultra · 512G',
      period: 'month_price',
      totalAmount: 1280,
      status: 0,
      createdAt: 1789516800,
    ),
  ];

  @override
  Future<List<RemoteOrder>> fetchOrders() async {
    fetchCalls++;
    if (fail) throw Exception('订单服务超时');
    final gate = this.gate;
    if (gate != null) return gate.future;
    return _orders;
  }
}

class _OrdersController extends VisualV3Controller {
  _OrdersController(this.ordersApi) : super(AppPage.dashboard);

  final _OrdersApi ordersApi;

  @override
  PanelApi get api => ordersApi;
}

Future<void> _pump(
  WidgetTester tester,
  VisualV3Controller controller,
  Widget page,
) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  addTearDown(controller.disposeVisual);
  await tester.pumpWidget(
    AppScope(
      controller: controller,
      child: MaterialApp(
        theme: V3Theme.light(),
        home: Scaffold(body: page),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _pumpAndTapRetry(
  WidgetTester tester,
  VisualV3Controller controller,
  Widget page,
) async {
  await _pump(tester, controller, page);
  await tester.pump();

  expect(find.byType(V3EmptyState), findsOneWidget);
  // Failure is not emptiness: the state names itself with the error icon.
  expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
  expect(find.byType(V3SkeletonBlock), findsNothing);

  await tester.tap(find.text('重试'));
  await tester.pump();
}

void main() {
  testWidgets('shop opens on plan skeletons while the first load runs', (
    tester,
  ) async {
    final controller = _EmptyPlansController(AppPage.shop, initialLoading: true);
    await _pump(tester, controller, const V3ShopPage());

    expect(find.byType(V3SkeletonBlock), findsWidgets);
    expect(find.byType(V3EmptyState), findsNothing);
    expect(find.textContaining('暂无'), findsNothing,
        reason: 'a first load must never read as an empty catalog');
  });

  testWidgets('shop names a failed catalog and the retry reaches refreshData', (
    tester,
  ) async {
    final controller =
        _EmptyPlansController(AppPage.shop, loadError: '套餐服务超时');
    await _pumpAndTapRetry(tester, controller, const V3ShopPage());

    expect(controller.refreshDataCalls, 1,
        reason: 'the retry tap must reach the controller, not a local no-op');
  });

  testWidgets('nodes overview opens on row skeletons while the first load runs', (
    tester,
  ) async {
    final controller = VisualV3Controller(AppPage.nodes, initialLoading: true);
    await _pump(tester, controller, const V3NodesPage());

    expect(find.byType(V3NodeSkeletonRow), findsNWidgets(3));
    expect(find.byType(V3EmptyState), findsNothing);
    expect(find.textContaining('暂无'), findsNothing);
  });

  testWidgets('nodes overview names a failed fleet and retry reaches refreshData', (
    tester,
  ) async {
    final controller =
        _EmptyNodesController(AppPage.nodes, loadError: '节点同步失败');
    await _pumpAndTapRetry(tester, controller, const V3NodesPage());

    expect(controller.refreshDataCalls, 1);
  });

  testWidgets('node picker opens on row skeletons while the first load runs', (
    tester,
  ) async {
    final controller = VisualV3Controller(AppPage.nodes, initialLoading: true);
    await _pump(tester, controller, const V3NodePicker());

    expect(find.byType(V3NodeSkeletonRow), findsNWidgets(3));
    expect(find.byType(V3EmptyState), findsNothing);
    expect(find.textContaining('暂无'), findsNothing);
  });

  testWidgets('node picker names a failed fleet and retry reaches refreshData', (
    tester,
  ) async {
    final controller =
        _EmptyNodesController(AppPage.nodes, loadError: '节点同步失败');
    await _pumpAndTapRetry(tester, controller, const V3NodePicker());

    expect(controller.refreshDataCalls, 1);
  });

  testWidgets('tickets open on a skeleton, not a false empty verdict', (
    tester,
  ) async {
    final controller = VisualV3Controller(AppPage.tickets, ticketsLoaded: false);
    await _pump(tester, controller, const V3TicketsPage());
    await tester.pump();

    expect(find.byType(V3SkeletonBlock), findsWidgets);
    expect(find.byType(V3EmptyState), findsNothing);
    expect(find.textContaining('还没有工单'), findsNothing,
        reason: 'an in-flight ticket load must not read as "no tickets"');
  });

  testWidgets('tickets name the failure and the retry reaches refreshTickets', (
    tester,
  ) async {
    final controller =
        VisualV3Controller(AppPage.tickets, ticketsError: '工单服务暂不可用');
    await _pump(tester, controller, const V3TicketsPage());
    await tester.pump();

    expect(find.byType(V3EmptyState), findsOneWidget);
    expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);

    // The page's mount-time refresh already ran once; the retry adds another.
    final before = controller.refreshTicketsCalls;
    await tester.tap(find.text('重试'));
    await tester.pump();

    expect(controller.refreshTicketsCalls, greaterThan(before));
  });

  testWidgets('orders open on a skeleton and hand in to the ledger', (
    tester,
  ) async {
    final api = _OrdersApi();
    final gate = Completer<List<RemoteOrder>>();
    api.gate = gate;
    final controller = _OrdersController(api);
    await _pump(tester, controller, const V3OrdersPage());
    await tester.pump();

    expect(api.fetchCalls, 1);
    expect(find.byType(V3SkeletonBlock), findsWidgets);
    expect(find.byType(V3EmptyState), findsNothing);
    expect(find.textContaining('这里还没有订单'), findsNothing,
        reason: 'an in-flight ledger load must not read as "no orders"');

    gate.complete(const [
      RemoteOrder(
        tradeNo: 'L202609160001',
        planName: 'Litchi Ultra · 512G',
        period: 'month_price',
        totalAmount: 1280,
        status: 0,
        createdAt: 1789516800,
      ),
    ]);
    await tester.pumpAndSettle();

    expect(find.textContaining('L202609160001'), findsOneWidget);
    expect(find.byType(V3SkeletonBlock), findsNothing);
  });

  testWidgets('orders name the failure and the retry reloads the ledger', (
    tester,
  ) async {
    final api = _OrdersApi()..fail = true;
    final controller = _OrdersController(api);
    await _pump(tester, controller, const V3OrdersPage());
    await tester.pumpAndSettle();

    expect(find.byType(V3EmptyState), findsOneWidget);
    expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);

    api.fail = false;
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();

    expect(api.fetchCalls, 2,
        reason: 'the retry reloads the ledger through the panel API');
    expect(find.textContaining('L202609160001'), findsOneWidget);
  });
}
