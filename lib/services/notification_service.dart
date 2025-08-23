import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final notificationServiceProvider = Provider((ref) => NotificationService());

class NotificationService {
  final _firebaseMessaging = FirebaseMessaging.instance;

  // TODO: Initialize notifications (request permissions, get token)
  Future<void> init() async {
    // ...
  }

  // TODO: Handle incoming messages
  void handleMessages() {
    // ...
  }
} 