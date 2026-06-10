import '../config/app_config.dart';
import 'api_models.dart';
import 'app_models.dart';

/// Pure static converters from remote API models to UI view models.
abstract final class ModelMappers {
  static UserModel toUser(RemoteUser info) {
    final name =
        info.email.contains('@') ? info.email.split('@').first : info.email;
    return UserModel(
      name: name,
      plan: info.planLabel,
      avatarLetter: name.isNotEmpty ? name[0].toUpperCase() : 'U',
      expiry: info.expiryDisplay,
    );
  }

  static TrafficModel toTraffic(RemoteUser info) {
    final total  = info.transferEnable / AppConfig.bytesPerGb;
    final used   = info.used / AppConfig.bytesPerGb;
    final remain = (total - used).clamp(0.0, double.infinity);
    return TrafficModel(totalGb: total, usedGb: used, remainGb: remain);
  }

  static NodeModel toNode(RemoteNode node) {
    final flag = _flagFor(node.name);
    return NodeModel(
      id: node.id.toString(),
      name: node.name,
      flag: flag,
      code: _codeFor(flag),
      englishName: _englishFor(flag),
      latency: 0,
      region: _regionFor(node.name),
      tags: node.rate > 1.0 ? ['Premium'] : [],
      server: node.server,
      port: node.port,
      rawUri: node.rawUri,
    );
  }

  static PlanModel toPlan(RemotePlan plan) {
    PlanCategory category;
    if (plan.monthPrice == null &&
        plan.quarterPrice == null &&
        plan.yearPrice == null) {
      category = plan.onetimePrice != null
          ? PlanCategory.oneTime
          : PlanCategory.dataPack;
    } else {
      category = PlanCategory.recurring;
    }

    final rawDesc = plan.description ?? '';
    final stripped = rawDesc
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');
    final features = stripped
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .take(6)
        .toList();

    return PlanModel(
      id: plan.id.toString(),
      title: plan.name,
      capacity: plan.capacityDisplay,
      category: category,
      monthlyPrice:   plan.monthPrice   != null ? plan.monthPrice!   / 100.0 : null,
      quarterlyPrice: plan.quarterPrice != null ? plan.quarterPrice! / 100.0 : null,
      yearlyPrice:    plan.yearPrice    != null ? plan.yearPrice!    / 100.0 : null,
      oneTimePrice:   plan.onetimePrice != null ? plan.onetimePrice! / 100.0 : null,
      features: features,
    );
  }

  // ── Flag / region helpers ─────────────────────────────────────────────────

  static String _flagFor(String name) {
    final n = name.toLowerCase();
    if (_any(n, ['新加坡', 'singapore', 'sg'])) return '🇸🇬';
    if (_any(n, ['香港', 'hong kong', 'hongkong', 'hk'])) return '🇭🇰';
    if (_any(n, ['日本', 'japan', 'jp', 'tokyo', 'osaka'])) return '🇯🇵';
    if (_any(n, ['台湾', 'taiwan', 'tw'])) return '🇹🇼';
    if (_any(n, ['韩国', 'korea', 'kr', 'seoul'])) return '🇰🇷';
    if (_any(n, ['美国', 'united states', 'usa', 'los angeles', 'new york', 'chicago'])) return '🇺🇸';
    if (_any(n, ['英国', 'united kingdom', 'london', 'britain'])) return '🇬🇧';
    if (_any(n, ['德国', 'germany', 'frankfurt', 'berlin'])) return '🇩🇪';
    if (_any(n, ['法国', 'france', 'paris'])) return '🇫🇷';
    if (_any(n, ['荷兰', 'netherlands', 'amsterdam'])) return '🇳🇱';
    if (_any(n, ['澳大利亚', 'australia', 'sydney', 'melbourne'])) return '🇦🇺';
    if (_any(n, ['加拿大', 'canada', 'toronto', 'vancouver'])) return '🇨🇦';
    if (_any(n, ['印度', 'india', 'mumbai'])) return '🇮🇳';
    if (_any(n, ['巴西', 'brazil'])) return '🇧🇷';
    if (_any(n, ['俄罗斯', 'russia', 'moscow'])) return '🇷🇺';
    if (_any(n, ['土耳其', 'turkey', 'istanbul'])) return '🇹🇷';
    if (_any(n, ['越南', 'vietnam'])) return '🇻🇳';
    if (_any(n, ['泰国', 'thailand', 'bangkok'])) return '🇹🇭';
    if (_any(n, ['马来西亚', 'malaysia', 'kuala lumpur'])) return '🇲🇾';
    if (_any(n, ['菲律宾', 'philippines', 'manila'])) return '🇵🇭';
    if (_any(n, ['印尼', 'indonesia', 'jakarta'])) return '🇮🇩';
    return '🌐';
  }

  static NodeRegion _regionFor(String name) {
    final n = name.toLowerCase();
    if (_any(n, [
      '新加坡', '香港', '日本', '台湾', '韩国', '印度', '越南', '泰国', '马来', '菲律宾', '印尼',
      'singapore', 'hong kong', 'japan', 'taiwan', 'korea', 'india',
      'tokyo', 'seoul', 'bangkok', 'asia',
    ])) return NodeRegion.asia;
    if (_any(n, [
      '英国', '德国', '法国', '荷兰', '俄罗斯', '土耳其',
      'uk', 'germany', 'france', 'netherlands', 'london',
      'frankfurt', 'amsterdam', 'europe',
    ])) return NodeRegion.europe;
    if (_any(n, [
      '美国', '加拿大', '巴西', 'usa', 'united states', 'canada', 'brazil',
      'los angeles', 'new york', 'america',
    ])) return NodeRegion.america;
    if (_any(n, ['澳大利亚', '新西兰', 'australia', 'sydney', 'melbourne'])) {
      return NodeRegion.oceania;
    }
    return NodeRegion.asia;
  }

  static bool _any(String s, List<String> keywords) =>
      keywords.any(s.contains);

  static String _codeFor(String flag) {
    final runes = flag.runes.toList();
    if (runes.length < 2) return '';
    final a = runes[0] - 0x1F1E6;
    final b = runes[1] - 0x1F1E6;
    if (a < 0 || a > 25 || b < 0 || b > 25) return '';
    return String.fromCharCodes([0x41 + a, 0x41 + b]);
  }

  static String _englishFor(String flag) {
    const m = {
      '🇸🇬': 'Singapore',      '🇭🇰': 'Hong Kong',
      '🇯🇵': 'Japan',          '🇹🇼': 'Taiwan',
      '🇰🇷': 'South Korea',    '🇺🇸': 'United States',
      '🇬🇧': 'United Kingdom', '🇩🇪': 'Germany',
      '🇫🇷': 'France',         '🇳🇱': 'Netherlands',
      '🇦🇺': 'Australia',      '🇨🇦': 'Canada',
      '🇮🇳': 'India',          '🇧🇷': 'Brazil',
      '🇷🇺': 'Russia',         '🇹🇷': 'Turkey',
      '🇻🇳': 'Vietnam',        '🇹🇭': 'Thailand',
      '🇲🇾': 'Malaysia',       '🇵🇭': 'Philippines',
      '🇮🇩': 'Indonesia',      '🇨🇳': 'China',
    };
    return m[flag] ?? '';
  }
}
