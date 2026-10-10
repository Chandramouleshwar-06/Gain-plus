import 'package:flutter/material.dart';
import '../../widgets/ui.dart';

/// Profile, goals and settings. Filled in by the profile & goals feature.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(title: 'Profile'),
            Expanded(
              child: EmptyState(
                icon: Icons.person_rounded,
                title: 'Coming next',
                message: 'Your profile, goals and settings will live here.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

