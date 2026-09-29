import 'dart:io';

import 'package:flutter/services.dart';

class AppPaths {
  const AppPaths({required this.channel, this.available = true});

  const AppPaths.android()
    : channel = const MethodChannel(channelName),
      available = true;

  const AppPaths.unavailable()
    : channel = const MethodChannel(channelName),
      available = false;

  final MethodChannel channel;
  final bool available;

  static const String channelName = 'com.cull.cull/paths';

  static const String databaseName = 'cull.db';

  Future<String> databasePath() async {
    final dir = await _resolve();
    return '$dir${Platform.pathSeparator}$databaseName';
  }

  Future<String> _resolve() async {
    if (available) {
      try {
        final value = await channel.invokeMethod<String>('getFilesDir');
        if (value != null && value.trim().isNotEmpty) return value.trim();
      } on PlatformException {
        return _fallback();
      } on MissingPluginException {
        return _fallback();
      }
    }
    return _fallback();
  }

  String _fallback() {
    if (Platform.isAndroid || Platform.isIOS) {
      return Directory.systemTemp.path;
    }
    return '${Directory.current.path}${Platform.pathSeparator}data';
  }
}
