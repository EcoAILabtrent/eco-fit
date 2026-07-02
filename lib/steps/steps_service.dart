import 'dart:async';

import 'package:flutter/services.dart';

/// Independent pedometer — talks to the native StepSamples engine
/// (MainActivity.kt + StepSamples/StepSampleWorker/BootReceiver.java).
///
/// The hardware chip counts 24/7; native WorkManager checkpoints split its
/// cumulative value into days, survive reboots, and — unlike StepsShare —
/// never discard large counter jumps (those are real steps accumulated while
/// the app slept).
class StepsService {
  StepsService._();
  static final instance = StepsService._();

  static const _channel = MethodChannel('eco/steps');
  static const _liveChannel = EventChannel('eco/steps/live');

  Future<bool> isAvailable() async {
    try {
      return await _channel.invokeMethod<bool>('isAvailable') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<bool> checkPermission() async {
    try {
      return await _channel.invokeMethod<bool>('checkPermission') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<bool> requestPermission() async {
    try {
      // Safety net: if the native side ever strands this call (e.g. the system
      // dialog is dismissed without a result), don't leave the caller's Future
      // hanging until app restart — resolve to "not granted" after 90 s.
      return await _channel
              .invokeMethod<bool>('requestPermission')
              .timeout(const Duration(seconds: 90), onTimeout: () => false) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Today's total (also records a fresh checkpoint). Null = no permission.
  Future<int?> getTodaySteps() async {
    try {
      return await _channel.invokeMethod<int>('getTodaySteps');
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// Steps recorded on a past [day] the native engine still keeps samples for
  /// (8-day window). Used to backfill days the app was closed. Null = no
  /// permission, no data, or the platform lacks the native bridge.
  Future<int?> stepsForDay(DateTime day) async {
    final start =
        DateTime(day.year, day.month, day.day).millisecondsSinceEpoch;
    try {
      return await _channel.invokeMethod<int>('getStepsForDay', start);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// Real-time totals while subscribed — the number ticks as the user walks.
  Stream<int> liveSteps() =>
      _liveChannel.receiveBroadcastStream().map((e) => (e as num).toInt());
}
