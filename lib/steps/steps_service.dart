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
      return await _channel.invokeMethod<bool>('requestPermission') ?? false;
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

  /// Real-time totals while subscribed — the number ticks as the user walks.
  Stream<int> liveSteps() =>
      _liveChannel.receiveBroadcastStream().map((e) => (e as num).toInt());
}
