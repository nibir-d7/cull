import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'design/theme.dart';
import 'onboarding/copy.dart';
import 'onboarding/onboarding.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(CullTheme.overlay);
  runApp(const CullApp());
}

class CullApp extends StatefulWidget {
  const CullApp({super.key});

  @override
  State<CullApp> createState() => _CullAppState();
}

class _CullAppState extends State<CullApp> {
  RoastTone _tone = RoastTone.blunt;
  bool _onboarded = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CULL',
      debugShowCheckedModeBanner: false,
      theme: CullTheme.dark(),
      home: _onboarded
          ? Scaffold(
              body: Center(
                child: Text(
                  'CULL',
                  style: Theme.of(context).textTheme.displayLarge,
                ),
              ),
            )
          : Onboarding(
              initialTone: _tone,
              onFinished: (t) => setState(() {
                _tone = t;
                _onboarded = true;
              }),
            ),
    );
  }
}
