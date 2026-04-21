import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';

import 'core/config/theme.dart';
import 'core/providers/locale_provider.dart';
import 'core/providers/theme_provider.dart';
import 'core/router/app_router.dart';
import 'services/notification_service.dart';

// Default to the shared test key so `flutter run` without --dart-define still
// lets Stripe Payment Sheet initialise. Override via:
//   --dart-define=STRIPE_PUBLISHABLE_KEY=pk_test_your_key
const stripePublishableKey = String.fromEnvironment(
  'STRIPE_PUBLISHABLE_KEY',
  defaultValue:
      'pk_test_51Sxd7VGtkdFFe1B5SLNRHhqdiHxfwGJlqdJeLADAsTB0DgxJsKQeYC9tQZ8HgjyUpzkMYEWdowoLJT7Sk3AeNLKp00aDdwCReQ',
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (stripePublishableKey.isNotEmpty) {
    Stripe.publishableKey = stripePublishableKey;
    await Stripe.instance.applySettings();
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
