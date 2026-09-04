import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../constants/colors.dart';

class CallScreen extends StatelessWidget {
  final String companionId;

  const CallScreen({super.key, required this.companionId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.primary),
                onPressed: () => context.pop(),
              ),
            ),
            const Spacer(),
            const CircleAvatar(
              radius: 60,
              backgroundColor: AppColors.surfaceLight,
              child: Icon(Icons.person, size: 60, color: AppColors.primary),
            ),
            const SizedBox(height: 24),
            const Text(
              'Calling...',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 24,
                letterSpacing: 2,
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(bottom: 60),
              child: FloatingActionButton(
                backgroundColor: Colors.red,
                onPressed: () => context.pop(),
                child: const Icon(Icons.call_end, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
