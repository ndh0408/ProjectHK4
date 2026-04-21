import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';

import 'core/config/theme.dart';
import 'core/providers/locale_provider.dart';
import 'core/providers/theme_provider.dart';
import 'core/router/app_router.dart';
import 'services/notification_service.dart';

// Stripe publishable key resolution order:
//   1) --dart-define=STRIPE_PUBLISHABLE_KEY=... at build/run time
//   2) STRIPE_PUBLISHABLE_KEY in mobile/.env (gitignored, loaded at runtime)
const _stripeKeyFromEnv = String.fromEnvironment(
  'STRIPE_PUBLISHABLE_KEY',
  defaultValue: '',
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('No .env file loaded (${e.runtimeType}); relying on --dart-define');
  }

  final stripePublishableKey = _stripeKeyFromEnv.isNotEmpty
      ? _stripeKeyFromEnv
      : (dotenv.maybeGet('STRIPE_PUBLISHABLE_KEY') ?? '');

  if (stripePublishableKey.isNotEmpty) {
    Stripe.publishableKey = stripePublishableKey;
    await Stripe.instance.applySettings();
  } else {
    debugPrint(
      'WARNING: STRIPE_PUBLISHABLE_KEY not set. Copy mobile/.env.example to mobile/.env '
      'or pass --dart-define=STRIPE_PUBLISHABLE_KEY=pk_test_... so Payment Sheet can load.',
    );
  }

  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: AppColors.surface,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
  }

  runApp(
    const ProviderScope(
      child: LumaApp(),
    ),
  );
}

class LumaApp extends ConsumerWidget {
  const LumaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final locale = ref.watch(localeProvider);
    final themeMode = ref.watch(themeModeProvider);

    ref.watch(notificationServiceInitializerProvider);

    return MaterialApp.router(
      title: 'LUMA',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ref.read(themeModeProvider.notifier).themeMode,
      routerConfig: router,
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('vi'),
      ],
    );
  }
}
