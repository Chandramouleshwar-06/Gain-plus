import 'package:flutter/material.dart';

enum AppTab { home, train, progress, profile }

/// Sub-tabs of the Train tab.
enum TrainSection { plans, schedule, exercises }

/// Which tab is showing. Lets any screen switch tabs without reaching into
/// the shell's state.
class NavProvider extends ChangeNotifier {
  AppTab tab = AppTab.home;
  TrainSection trainSection = TrainSection.plans;

  void goTo(AppTab newTab, {TrainSection? section}) {
    tab = newTab;
    if (section != null) trainSection = section;
    notifyListeners();
  }
}
