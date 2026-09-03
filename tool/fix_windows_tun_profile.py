from pathlib import Path

config_path = Path('lib/shared/services/sing_box_config.dart')
test_path = Path('test/tun_config_defaults_test.dart')

config = config_path.read_text(encoding='utf-8')

anchor = "  static String nodeTagFor(NodeModel node) => 'node-${node.id}';\n"
insert = """  static String nodeTagFor(NodeModel node) => 'node-${node.id}';

  /// Windows Wintun startup is sensitive to jumbo MTUs and aggressive route
  /// locking. Keep Windows conservative while retaining the existing profile
  /// on macOS/Linux.
  static ({int mtu, bool strictRoute}) tunRouteProfile({
    required bool isWindows,
  }) => isWindows
      ? (mtu: 1500, strictRoute: false)
      : (mtu: 9000, strictRoute: true);
"""
if 'tunRouteProfile' not in config:
    if anchor not in config:
        raise SystemExit('nodeTagFor anchor not found')
    config = config.replace(anchor, insert, 1)

old_selected = """    final selected = nodeTags.contains(selectedTag)
        ? selectedTag
        : nodeTags.first;
    return {
"""
new_selected = """    final selected = nodeTags.contains(selectedTag)
        ? selectedTag
        : nodeTags.first;
    final tunProfile = tunRouteProfile(isWindows: Platform.isWindows);
    return {
"""
if new_selected not in config:
    if old_selected not in config:
        raise SystemExit('selected outbound anchor not found')
    config = config.replace(old_selected, new_selected, 1)

old_tun = """            'mtu': 9000,
            'auto_route': true,
            'strict_route': true,
            'stack': 'system',
"""
new_tun = """            'mtu': tunProfile.mtu,
            'auto_route': true,
            'strict_route': tunProfile.strictRoute,
            'stack': 'system',
"""
if new_tun not in config:
    if old_tun not in config:
        raise SystemExit('TUN route defaults block not found')
    config = config.replace(old_tun, new_tun, 1)

config_path.write_text(config, encoding='utf-8')

test = test_path.read_text(encoding='utf-8')
old_title = "  test('TUN uses the standard system stack with strict routing', () {"
new_title = "  test('TUN config uses the platform route profile', () {"
if old_title in test:
    test = test.replace(old_title, new_title, 1)

if "Windows TUN keeps conservative Wintun defaults" not in test:
    insert_before = "\n  test('TUN config uses the platform route profile', () {"
    tests = """
  test('Windows TUN keeps conservative Wintun defaults', () {
    final profile = SingBoxConfig.tunRouteProfile(isWindows: true);
    expect(profile.mtu, 1500);
    expect(profile.strictRoute, isFalse);
  });

  test('non-Windows TUN keeps the existing route profile', () {
    final profile = SingBoxConfig.tunRouteProfile(isWindows: false);
    expect(profile.mtu, 9000);
    expect(profile.strictRoute, isTrue);
  });
"""
    if insert_before not in test:
        raise SystemExit('TUN test insertion anchor not found')
    test = test.replace(insert_before, tests + insert_before, 1)

# The existing build-config assertion runs on Linux CI and should continue to
# validate the non-Windows branch. Explicit helper tests above cover Windows.
test_path.write_text(test, encoding='utf-8')
