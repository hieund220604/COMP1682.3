import 'package:flutter/widgets.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Centralized icon mapping so the app doesn't depend on icon packages directly.
@immutable
class AppIcons {
  // Navigation / actions
  static const IconData home = Symbols.home_rounded;
  static const IconData back = Symbols.arrow_back_rounded;
  static const IconData chevronRight = Symbols.chevron_right_rounded;
  static const IconData close = Symbols.close_rounded;
  static const IconData search = Symbols.search_rounded;
  static const IconData add = Symbols.add_rounded;
  static const IconData delete = Symbols.delete_rounded;
  static const IconData refresh = Symbols.refresh_rounded;
  static const IconData more = Symbols.more_vert_rounded;
  static const IconData menu = Symbols.menu_rounded;
  static const IconData calendar = Symbols.calendar_today_rounded;
  static const IconData arrowForward = Symbols.arrow_forward_rounded;
  static const IconData checkCircle = Symbols.check_circle_rounded;
  static const IconData info = Symbols.info_rounded;
  static const IconData key = Symbols.vpn_key_rounded;
  static const IconData star = Symbols.star_rounded;
  static const IconData settings = Symbols.settings_rounded;
  static const IconData logout = Symbols.logout_rounded;
  static const IconData palette = Symbols.palette_rounded;
  static const IconData camera = Symbols.photo_camera_rounded;

  // Product / entities
  static const IconData groups = Symbols.groups_rounded;
  static const IconData memberAdd = Symbols.person_add_rounded;
  static const IconData mail = Symbols.mail_rounded;
  static const IconData notifications = Symbols.notifications_rounded;
  static const IconData wallet = Symbols.account_balance_wallet_rounded;
  static const IconData bank = Symbols.account_balance_rounded;

  // Group detail tabs
  static const IconData overview = Symbols.dashboard_rounded;
  static const IconData invoices = Symbols.receipt_long_rounded;
  static const IconData payments = Symbols.payments_rounded;
  static const IconData subscriptions = Symbols.credit_card_rounded;

  // Messaging
  static const IconData chat = Symbols.chat_rounded;
  static const IconData chatBubble = Symbols.chat_bubble_rounded;

  // Status
  static const IconData draft = Symbols.edit_rounded;
  static const IconData submitted = Symbols.send_rounded;
  static const IconData locked = Symbols.lock_rounded;
  static const IconData paused = Symbols.pause_circle_rounded;

  // Person
  static const IconData person = Symbols.person_rounded;

  const AppIcons._();
}
