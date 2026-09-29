import 'package:flutter/services.dart';

class SharedUrl {
  const SharedUrl({required this.channel, this.available = true});

  const SharedUrl.android()
    : channel = const MethodChannel(channelName),
      available = true;

  final MethodChannel channel;
  final bool available;

  static const String channelName = 'com.cull.cull/share';

  Future<String?> take() async {
    if (!available) return null;
    try {
      final value = await channel.invokeMethod<String>('getSharedUrl');
      if (value == null || value.trim().isEmpty) return null;
      await channel.invokeMethod<bool>('consumeSharedUrl');
      return value.trim();
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}
