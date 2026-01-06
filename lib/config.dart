import 'package:firebase_core/firebase_core.dart';

// ========== CONFIGURAÇÃO ==========
// ✅ MUDA PARA false QUANDO COMPILAR PARA PRODUÇÃO
const bool kUseDevFirebase = false;

// ========== EMAILS AUTORIZADOS NO DEV ==========
const List<String> allowedDevEmails = [
  'teste@teste.com',
  'edroq@2windservice.com',
  'tu-dev@gmail.com' // ✅ ADICIONA MAIS EMAILS AQUI SE NECESSÁRIO
];

// ========== FIREBASE OPTIONS ==========
FirebaseOptions get firebaseOptions {
  if (kUseDevFirebase) {
    // 🧪 DEV: walkdown-dev
    return const FirebaseOptions(
      apiKey: "AIzaSyAdYu8vGkHvleUfvqQxn3WHsed7dGsYELA",
      appId: "1:288816615806:android:454352d7b0281fbeffa32f",
      messagingSenderId: "288816615806",
      projectId: "walkdown-dev",
      storageBucket: "walkdown-dev.firebasestorage.app",
    );
  }

  // 🚀 PRODUÇÃO: walkdown-sync
  return const FirebaseOptions(
    apiKey: "AIzaSyDzwmz7LwUb7jKjTcH_djxFw13sO8277Ec",
    appId: "1:377776819316:android:ef8ad0a81046584a889521",
    messagingSenderId: "377776819316",
    projectId: "walkdown-sync",
    storageBucket: "walkdown-sync.firebasestorage.app",
  );
}

// ========== VERIFICAR SE EMAIL É PERMITIDO NO DEV ==========
bool isEmailAllowedInDev(String? email) {
  if (!kUseDevFirebase) {
    return true; // Produção: todos permitidos
  }

  if (email == null) {
    return false;
  }

  return allowedDevEmails.contains(email.toLowerCase().trim());
}
