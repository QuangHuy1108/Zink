import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:io';

// 1. Khai báo Plugin thông báo cục bộ
final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

// 2. Hàm xử lý thông báo khi app đang TẮT (Background Handler)
// Bắt buộc phải là top-level function (nằm ngoài class)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("Đã nhận thông báo ngầm: ${message.messageId}");
  // Tại đây bạn không thể cập nhật UI, chỉ có thể xử lý logic ngầm
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  // Khởi tạo dịch vụ
  Future<void> initialize() async {
    // A. Xin quyền thông báo (cho Android 13+ và iOS)
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('Người dùng đã cấp quyền thông báo');
    } else {
      print('Người dùng từ chối quyền thông báo');
      return;
    }

    // B. Cấu hình kênh thông báo cho Android (Quan trọng để hiện Heads-up notification)
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel', // id trùng với AndroidManifest
      'Thông báo quan trọng', // title
      description: 'Kênh này dùng cho các thông báo quan trọng của Zink.', // description
      importance: Importance.max,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // C. Khởi tạo Local Notifications
    const AndroidInitializationSettings androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher'); // Icon app

    const InitializationSettings initSettings =
    InitializationSettings(android: androidSettings);

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        // Xử lý khi người dùng bấm vào thông báo lúc app đang mở
        print("Người dùng bấm vào thông báo: ${details.payload}");
      },
    );

    // D. Lắng nghe thông báo khi App đang MỞ (Foreground)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print("Nhận thông báo khi app đang mở: ${message.notification?.title}");

      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      // Nếu có thông báo, tự hiển thị banner bằng Local Notification
      if (notification != null && android != null) {
        _localNotifications.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              channel.id,
              channel.name,
              channelDescription: channel.description,
              icon: android.smallIcon,
              importance: Importance.max,
              priority: Priority.high,
            ),
          ),
        );
      }
    });

    // E. Lấy FCM Token (Gửi token này lên server để server biết bắn tin cho ai)
    String? token = await _firebaseMessaging.getToken();
    print("FCM Token của thiết bị: $token");
    // TODO: Bạn cần lưu token này vào Firestore (users/{uid}/fcmToken)
  }
}