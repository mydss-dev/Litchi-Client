import 'package:lucide_icons_flutter/lucide_icons.dart';

/// The app's icon vocabulary.
///
/// One family, one optical weight: every glyph comes from Lucide's 24px grid
/// with a 2px stroke, so a rail icon, a row chevron and a toast mark all read
/// as the same drawing. Material's filled/outlined pairs are deliberately not
/// used — selection is expressed with color and the pill underneath, never by
/// swapping to a heavier glyph.
///
/// Widgets must reference these names instead of `Icons.*` or `LucideIcons.*`
/// directly, so re-skinning the app stays a single-file change.
class AppIcons {
  AppIcons._();

  // ── Destinations ──────────────────────────────────────────────────────────
  static const connection = LucideIcons.house;
  static const nodes = LucideIcons.server;
  static const plans = LucideIcons.crown;
  static const account = LucideIcons.userRound;
  static const orders = LucideIcons.receiptText;
  static const traffic = LucideIcons.chartLine;
  static const invite = LucideIcons.gift;
  static const support = LucideIcons.messagesSquare;
  static const settings = LucideIcons.settings;
  static const redeem = LucideIcons.ticket;
  static const more = LucideIcons.ellipsis;

  // ── Navigation chrome ─────────────────────────────────────────────────────
  static const chevronRight = LucideIcons.chevronRight;
  static const chevronLeft = LucideIcons.chevronLeft;
  static const chevronDown = LucideIcons.chevronDown;
  static const chevronUp = LucideIcons.chevronUp;
  static const arrowUp = LucideIcons.arrowUp;
  static const arrowDown = LucideIcons.arrowDown;
  static const arrowUpCircle = LucideIcons.circleArrowUp;
  static const close = LucideIcons.x;
  static const menu = LucideIcons.menu;
  static const externalLink = LucideIcons.externalLink;
  static const expand = LucideIcons.maximize2;
  static const collapse = LucideIcons.minimize2;

  // ── Actions ───────────────────────────────────────────────────────────────
  static const add = LucideIcons.plus;
  static const remove = LucideIcons.minus;
  static const check = LucideIcons.check;
  static const checkCircle = LucideIcons.circleCheck;
  static const refresh = LucideIcons.refreshCw;
  static const sync = LucideIcons.refreshCw;
  static const copy = LucideIcons.copy;
  static const send = LucideIcons.send;
  static const search = LucideIcons.search;
  static const searchOff = LucideIcons.searchX;
  static const filtered = LucideIcons.squareDashed;
  static const swap = LucideIcons.arrowLeftRight;
  static const power = LucideIcons.power;
  static const stop = LucideIcons.powerOff;
  static const logout = LucideIcons.logOut;
  static const download = LucideIcons.download;
  static const sliders = LucideIcons.slidersHorizontal;
  static const scan = LucideIcons.scanLine;
  static const wrench = LucideIcons.wrench;
  static const listChecks = LucideIcons.listChecks;

  // ── Feedback ──────────────────────────────────────────────────────────────
  static const info = LucideIcons.info;
  static const warning = LucideIcons.triangleAlert;
  static const error = LucideIcons.circleAlert;
  static const help = LucideIcons.circleHelp;
  static const loader = LucideIcons.loaderCircle;

  // ── Privacy / state ───────────────────────────────────────────────────────
  static const visible = LucideIcons.eye;
  static const hidden = LucideIcons.eyeOff;
  static const shield = LucideIcons.shield;
  static const shieldOff = LucideIcons.shieldOff;
  static const lock = LucideIcons.lock;
  static const key = LucideIcons.keyRound;
  static const link = LucideIcons.link;
  static const linkOff = LucideIcons.link2Off;
  static const cloudOff = LucideIcons.cloudOff;
  static const globe = LucideIcons.globe;
  static const globeOff = LucideIcons.globeOff;
  static const zap = LucideIcons.zap;
  static const sparkles = LucideIcons.sparkles;
  static const verified = LucideIcons.badgeCheck;
  static const brand = LucideIcons.aperture;
  static const broadcast = LucideIcons.megaphone;
  static const sleep = LucideIcons.moon;
  static const daylight = LucideIcons.sun;
  static const language = LucideIcons.languages;

  // ── Commerce ──────────────────────────────────────────────────────────────
  static const wallet = LucideIcons.wallet;
  static const card = LucideIcons.creditCard;
  static const gift = LucideIcons.gift;
  static const receipt = LucideIcons.receiptText;
  static const bank = LucideIcons.landmark;
  static const package = LucideIcons.package;
  static const store = LucideIcons.store;
  static const shoppingBag = LucideIcons.shoppingBag;
  static const gem = LucideIcons.gem;

  // ── Infrastructure ────────────────────────────────────────────────────────
  static const server = LucideIcons.server;
  static const database = LucideIcons.database;
  static const network = LucideIcons.network;
  static const radar = LucideIcons.radar;
  static const gauge = LucideIcons.gauge;
  static const chartLine = LucideIcons.chartLine;
  static const chartBar = LucideIcons.chartBar;
  static const chartStacked = LucideIcons.chartColumnStacked;
  static const activity = LucideIcons.activity;
  static const devices = LucideIcons.monitorSmartphone;
  static const clock = LucideIcons.clock;
  static const message = LucideIcons.messageCircle;
  static const headset = LucideIcons.headset;
  static const user = LucideIcons.user;
  static const userPlus = LucideIcons.userPlus;
  static const grid = LucideIcons.layoutGrid;
}

/// Optical sizes for [AppIcons]. Lucide's 24px grid means a 16px glyph keeps a
/// 1.33px stroke; below 14px the drawing turns to mush, so that is the floor.
class AppIconSize {
  AppIconSize._();

  static const double xs = 14;
  static const double sm = 16;
  static const double md = 18;
  static const double lg = 20;
  static const double xl = 22;
  static const double hero = 28;
}
