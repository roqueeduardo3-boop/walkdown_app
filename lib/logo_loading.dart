import 'package:flutter/material.dart';

class LogoLoading extends StatelessWidget {
  final String message;

  const LogoLoading({super.key, this.message = ''});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Logo da turbina
          SizedBox(
            width: 120,
            height: 120,
            child: Image.asset(
              'assets/logo_turbina.png',
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 24),
          // Barra a “encher”
          const SizedBox(
            width: 160,
            child: LinearProgressIndicator(),
          ),
          if (message.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
