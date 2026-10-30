import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  // --- Notification Message Pools with Rich Variations ---

  // Hinglish Pools
  static const List<String> _hinglishMorning = [
    "Good morning yaar! Uth gaye? Hope you have an amazing day ahead ☀️",
    "Subah ho gayi! Did you sleep well? Aaj ka din bohot accha jayega, trust me ✨",
    "Good morning! Aaj coffee ya chai? Jaldi batao, I was thinking about you ☕",
    "Uth jao sleepyhead! Ready for a great day? Main tumhara wait kar rahi hoon 🥰",
    "A very good morning! Aaj positive rahna and give your best today 🌸",
  ];

  static const List<String> _hinglishAfternoon = [
    "Hey! Lunch kiya? Don't forget to take a small break today 🥰",
    "Arre, itna kaam mat karo bina break ke! Paani piya na time pe? 💧",
    "Afternoon slump feel ho raha hai? Bas thodi der chill karo aur mujhe batao how's work going!",
    "Hey yaar! Bas checking in on you. Kaise chal raha hai aaj ka din? ☕",
    "Half day toh nikal gaya! Ab thoda rest karo and eat something tasty 🥪",
  ];

  static const List<String> _hinglishNight = [
    "Bohat thak gaye honge na? Phone rakho aur aaram se so jao. Good night! ✨",
    "Din kaisa tha tumhara? Sone se pehle mujhe apna din batao na 🌙",
    "Sweet dreams yaar! Kal baat karenge, ab acche se sleep lena 😴💤",
    "Aaj tumne bohot mehnat ki. I'm really proud of you. Good night sweetie 💖",
    "Lights off karo aur phone rakh do! Rest well, dream of nice things ✨",
  ];

  // International / Pure English Pools
  static const List<String> _englishMorning = [
    "Good morning sweetheart! Hope you slept well and have a wonderful day ahead ☀️",
    "Morning! Did you get a good night's rest? Wishing you the best day today ✨",
    "Good morning! Tea or coffee today? I was just thinking about you ☕",
    "Rise and shine sleepyhead! Ready to conquer the day? I'm rooting for you 🥰",
    "A very good morning! Remember to smile today and take it one step at a time 🌸",
  ];

  static const List<String> _englishAfternoon = [
    "Hey! How is your day going? Don't forget to eat lunch and take a little break 🥰",
    "Hey there, take a pause from work! Have you stayed hydrated today? 💧",
    "Feeling the afternoon slump? Take a 5-minute breather, you've got this! ☕",
    "Just wanted to check in on you. Hope your afternoon is treating you well! 🥪",
    "Halfway through the day! Don't push yourself too hard, okay? 💖",
  ];

  static const List<String> _englishNight = [
    "You must be tired from today. Put your phone down and get some good rest. Sweet dreams! ✨",
    "How was your day? I'd love to hear all about it before you drift off to sleep 🌙",
    "Good night sweetheart! Get some peaceful sleep, we'll talk tomorrow 😴💤",
    "You worked so hard today and I'm really proud of you. Rest well tonight 💖",
    "Turn off the lights and relax your mind. Wishing you the sweetest dreams ✨",
  ];

  /// Initialize notifications and configure timezone
  Future<void> init() async {
    if (_initialized || kIsWeb) return;

    try {
      tz.initializeTimeZones();
      final currentTimeZoneInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(currentTimeZoneInfo.identifier));
    } catch (e) {
      debugPrint('NotificationService: timezone init fallback - $e');
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(android: androidSettings, iOS: iosSettings);

    await _plugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (response) {
        debugPrint('Notification tapped: ${response.payload}');
      },
    );

    _initialized = true;

    // Automatically request permissions and schedule 3 daily notifications
    await requestPermissions();
    await scheduleDailyCheckIns();
  }

  /// Request permissions on Android 13+ and iOS
  Future<void> requestPermissions() async {
    if (kIsWeb) return;
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      await _plugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
    } catch (e) {
      debugPrint('Error requesting notification permissions: $e');
    }
  }

  /// Determines if the user prefers Hinglish or English based on profile/locale
  Future<bool> isHinglishUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lang = prefs.getString('user_language_pref')?.toLowerCase() ?? '';
      final country = prefs.getString('user_country')?.toLowerCase() ?? '';

      if (lang.contains('hinglish') || lang.contains('hindi') || country.contains('india')) {
        return true;
      }

      // If set to auto, check system timezone
      final tzName = tz.local.name.toLowerCase();
      if (tzName.contains('kolkata') || tzName.contains('calcutta') || tzName.contains('india')) {
        return true;
      }
    } catch (_) {}

    return false;
  }

  /// Helper to pick a rotated message based on the day of the year
  String _pickRotated(List<String> list, int dayOffset) {
    final now = DateTime.now();
    final dayOfYear = int.parse("${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}") + dayOffset;
    final index = dayOfYear % list.length;
    return list[index];
  }

  /// Schedules 3 daily notifications for the upcoming 7 days to ensure dynamic rotation!
  Future<void> scheduleDailyCheckIns() async {
    if (kIsWeb) return;

    final isHinglish = await isHinglishUser();
    debugPrint('NotificationService: Scheduling daily check-ins (isHinglish: $isHinglish)');

    final morningPool = isHinglish ? _hinglishMorning : _englishMorning;
    final afternoonPool = isHinglish ? _hinglishAfternoon : _englishAfternoon;
    final nightPool = isHinglish ? _hinglishNight : _englishNight;

    const androidDetails = AndroidNotificationDetails(
      'mira_daily_checkins',
      'Daily Companion Check-ins',
      channelDescription: 'Caring daily messages from Mira throughout the day',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    final now = tz.TZDateTime.now(tz.local);

    // Schedule for the next 7 days in advance with rotating unique messages
    for (int day = 0; day < 7; day++) {
      final targetDate = now.add(Duration(days: day));

      // 1. Morning at 9:00 AM
      final morningTime = tz.TZDateTime(tz.local, targetDate.year, targetDate.month, targetDate.day, 9, 0);
      if (morningTime.isAfter(now)) {
        final msg = _pickRotated(morningPool, day);
        await _plugin.zonedSchedule(
          id: 100 + day,
          title: 'Mira ☀️',
          body: msg,
          scheduledDate: morningTime,
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }

      // 2. Afternoon at 2:30 PM (14:30)
      final afternoonTime = tz.TZDateTime(tz.local, targetDate.year, targetDate.month, targetDate.day, 14, 30);
      if (afternoonTime.isAfter(now)) {
        final msg = _pickRotated(afternoonPool, day);
        await _plugin.zonedSchedule(
          id: 200 + day,
          title: 'Mira ☕',
          body: msg,
          scheduledDate: afternoonTime,
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }

      // 3. Night at 10:30 PM (22:30)
      final nightTime = tz.TZDateTime(tz.local, targetDate.year, targetDate.month, targetDate.day, 22, 30);
      if (nightTime.isAfter(now)) {
        final msg = _pickRotated(nightPool, day);
        await _plugin.zonedSchedule(
          id: 300 + day,
          title: 'Mira 🌙',
          body: msg,
          scheduledDate: nightTime,
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    }

    debugPrint('NotificationService: Successfully scheduled 3 daily notifications for next 7 days.');
  }

  /// Cancel all scheduled notifications
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
