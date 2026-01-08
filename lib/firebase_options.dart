// File modified to respect config.dart DEV/PROD switch
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'config.dart'; // ✅ IMPORTA CONFIG

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    // ✅ USA O firebaseOptions DO CONFIG.DART
    // Isso respeita o kUseDevFirebase
    return firebaseOptions;
  }

  // ========== MANTIDO PARA COMPATIBILIDADE ==========
  // (Mas não é usado - config.dart controla tudo)

  static const FirebaseOptions androidProd = FirebaseOptions(
    apiKey: 'AIzaSyDzwmz7LwUb7jKjTcH_djxFw13sO8277Ec',
    appId: '1:377776819316:android:ef8ad0a81046584a889521',
    messagingSenderId: '377776819316',
    projectId: 'walkdown-sync',
    storageBucket: 'walkdown-sync.firebasestorage.app',
  );

  static const FirebaseOptions windowsProd = FirebaseOptions(
    apiKey: 'AIzaSyDAu9gc1wvFi8abXOQD4dUc_2VsD9CMxJs',
    appId: '1:377776819316:web:6e0e6edd76cb3466889521',
    messagingSenderId: '377776819316',
    projectId: 'walkdown-sync',
    authDomain: 'walkdown-sync.firebaseapp.com',
    storageBucket: 'walkdown-sync.firebasestorage.app',
  );
}
