// From relay lib/core/ports/notifier.dart @ 09b28810, with viaticum
// lib/core/ports/notifier.dart @ 78d38e0's ensureChannels and silent channel;
// the channel is the app's own spec, never the package's (D-APK-021).

/// System notifications with actions, on `flutter_local_notifications`
/// (`LocalNotifier`).
///
/// Actions follow RELAY's P3-R6: one that runs in the background dismisses
/// the notification; one that opens the app, and a tap on the body, leave it,
/// so the app cancels it once the user has chosen, and backing out of the app
/// lock never loses it.
abstract interface class Notifier {
  /// Creates [channels] with their importance and sound; safe to call on
  /// every start (Android keeps a channel's settings by its id). Two specs
  /// with one id are an [ArgumentError].
  Future<void> ensureChannels(List<NotificationChannelSpec> channels);

  /// Shows [notification], replacing any with the same ID.
  Future<void> show(AppNotification notification);

  /// Cancels the notification with [notificationId], if it is showing.
  Future<void> cancel(int notificationId);

  /// Taps on notifications, and on the actions that open the app, while the
  /// app runs. Background actions go to the background entry point instead.
  Stream<NotificationResponse> get responses;

  /// The tap or action that started the app, if one did: answered once, then
  /// null.
  Future<NotificationResponse?> launchResponse();

  /// Whether the user allows the app's notifications (`POST_NOTIFICATIONS`),
  /// without asking.
  Future<bool> permissionGranted();

  /// Asks the user for `POST_NOTIFICATIONS`; true when granted. No answer
  /// (no activity to ask from) is a refusal.
  Future<bool> requestPermission();

  /// Opens the app's notification settings in the system settings.
  Future<void> openNotificationSettings();
}

/// How a channel interrupts: Android fixes it when it first creates the
/// channel, and the user may change it later. A notification's priority
/// (before Android 8) follows it.
enum NotificationImportance { low, defaultImportance, high }

/// What the system may do with a notification (do-not-disturb rules): a
/// reminder, or a calendar event.
enum NotificationCategory { reminder, event }

/// One of the app's notification channels. [id] is the app's own and must
/// never change: Android keys a user's settings for the channel by it, so a
/// new id resets them and leaves a second channel in the system settings.
/// [name] and [description] are localised by the app.
final class NotificationChannelSpec {
  const NotificationChannelSpec(
    this.id,
    this.name, {
    this.importance = NotificationImportance.defaultImportance,
    this.description,
    this.silent = false,
    this.category,
    this.privateOnLockScreen = false,
  });

  /// The spec back from [toJson] (an alarm's background engine posts under
  /// the same channel); a [FormatException] when a field is missing or of
  /// the wrong type.
  factory NotificationChannelSpec.fromJson(Map<String, Object?> json) {
    String text(String key) => switch (json[key]) {
      final String value => value,
      _ => throw FormatException('notification channel: no $key'),
    };
    T named<T extends Enum>(List<T> values, String key) {
      final name = text(key);
      for (final value in values) {
        if (value.name == name) return value;
      }
      throw FormatException('notification channel: $key "$name"');
    }

    bool flag(String key) => switch (json[key]) {
      final bool value => value,
      _ => throw FormatException('notification channel: no $key'),
    };

    return NotificationChannelSpec(
      text('id'),
      text('name'),
      importance: named(NotificationImportance.values, 'importance'),
      description: switch (json['description']) {
        final String value => value,
        null => null,
        _ => throw const FormatException('notification channel: description'),
      },
      silent: flag('silent'),
      category: json['category'] == null
          ? null
          : named(NotificationCategory.values, 'category'),
      privateOnLockScreen: flag('privateOnLockScreen'),
    );
  }

  final String id;
  final String name;
  final NotificationImportance importance;
  final String? description;

  /// No sound and no vibration, whatever the phone is set to (VIATICUM's
  /// `quiet`, for the reading room).
  final bool silent;

  final NotificationCategory? category;

  /// On a secure lock screen the content stays hidden: the system shows the
  /// notification's [AppNotification.publicTitle], or else the app's name and
  /// the time.
  final bool privateOnLockScreen;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'importance': importance.name,
    'description': description,
    'silent': silent,
    'category': category?.name,
    'privateOnLockScreen': privateOnLockScreen,
  };

  @override
  bool operator ==(Object other) =>
      other is NotificationChannelSpec &&
      other.id == id &&
      other.name == name &&
      other.importance == importance &&
      other.description == description &&
      other.silent == silent &&
      other.category == category &&
      other.privateOnLockScreen == privateOnLockScreen;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    importance,
    description,
    silent,
    category,
    privateOnLockScreen,
  );

  @override
  String toString() => 'NotificationChannelSpec($id)';
}

/// A notification to show. [title], [body], [publicTitle] and the action
/// labels are already localised by the caller; [payload] carries IDs only,
/// never note content.
final class AppNotification {
  const AppNotification({
    required this.notificationId,
    required this.title,
    required this.body,
    required this.channel,
    this.payload,
    this.actions = const [],
    this.group,
    this.publicTitle,
    this.dismissOnTap = false,
  });

  /// At most three actions: Android shows no more.
  static const maxActions = 3;

  final int notificationId;
  final String title;
  final String body;
  final NotificationChannelSpec channel;
  final String? payload;
  final List<NotificationAction> actions;

  /// The group the system bundles it with (a calendar day's reminders); null
  /// for none.
  final String? group;

  /// What a secure lock screen shows in its place while the content is
  /// hidden ("Reminder · 18:55"): never note content; null for the system's
  /// redacted version (the app's name and the time).
  final String? publicTitle;

  /// Whether a tap on the body also dismisses it (VIATICUM's notifications,
  /// which have no actions). By default it stays until the app cancels it.
  final bool dismissOnTap;

  /// Prints the ID and channel only: titles and bodies are never logged.
  @override
  String toString() => 'AppNotification($notificationId, ${channel.id})';
}

/// A button on a notification: [actionId] is stable, [label] is localised.
/// One that [opensApp] brings the app forward and leaves the notification;
/// one that does not runs in the background and dismisses it.
final class NotificationAction {
  const NotificationAction({
    required this.actionId,
    required this.label,
    this.opensApp = false,
  });

  final String actionId;
  final String label;
  final bool opensApp;
}

/// The user tapped a notification ([actionId] null) or one of its actions.
final class NotificationResponse {
  const NotificationResponse({
    required this.notificationId,
    this.actionId,
    this.payload,
  });

  final int notificationId;
  final String? actionId;
  final String? payload;

  @override
  bool operator ==(Object other) =>
      other is NotificationResponse &&
      other.notificationId == notificationId &&
      other.actionId == actionId &&
      other.payload == payload;

  @override
  int get hashCode => Object.hash(notificationId, actionId, payload);

  @override
  String toString() => 'NotificationResponse($notificationId, $actionId)';
}
