import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:focus_town/platform/notifier.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Id of the immediate "10 seconds" warning.
const kWarningNotificationId = 1001;

/// Id of the scheduled "emergency pass" warning.
const kPassNotificationId = 1002;

const _passDelay = Duration(seconds: 10);

const _details = NotificationDetails(
  iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
);

/// [Notifier] backed by `flutter_local_notifications` (iOS only for now).
class LocalNotifier implements Notifier {
  /// Creates the notifier; call [initialize] once before use.
  new([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  /// Sets up the plugin and time zones. Permission is not asked here.
  Future<void> initialize() async {
    tz_data.initializeTimeZones();
    // shortcut: the time zone is fixed to EST for testing, detect the device
    // zone before release (needs a package, ask the user first).
    tz.setLocalLocation(tz.getLocation('America/New_York'));
    await _plugin.initialize(
      settings: const InitializationSettings(
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestSoundPermission: false,
          requestBadgePermission: false,
        ),
      ),
    );
  }

  IOSFlutterLocalNotificationsPlugin? get _ios => _plugin
      .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin
      >();

  @override
  Future<bool> requestPermission() async =>
      await _ios?.requestPermissions(alert: true, sound: true) ?? false;

  @override
  Future<bool> hasPermission() async =>
      (await _ios?.checkPermissions())?.isEnabled ?? false;

  @override
  Future<void> scheduleAwayWarnings({required bool passAvailable}) async {
    await _plugin.show(
      id: kWarningNotificationId,
      title: 'Focus Town',
      body: 'Come back! Your builders stop in 10 seconds.',
      notificationDetails: _details,
    );
    if (!passAvailable) return;
    await _plugin.zonedSchedule(
      id: kPassNotificationId,
      title: 'Focus Town',
      body: 'Emergency pass used. You have 60 seconds.',
      scheduledDate: tz.TZDateTime.now(tz.local).add(_passDelay),
      notificationDetails: _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  @override
  Future<void> cancelAwayWarnings() async {
    await _plugin.cancel(id: kWarningNotificationId);
    await _plugin.cancel(id: kPassNotificationId);
  }
}
