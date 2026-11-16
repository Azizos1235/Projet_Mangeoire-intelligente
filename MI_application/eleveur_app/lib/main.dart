import 'package:flutter/material.dart';
import 'core/app_routes.dart';
import 'core/l10n.dart';
import 'core/theme.dart';
import 'services/api_client.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() {
  ApiClient.instance.navigatorKey = navigatorKey;
  runApp(const EleveurApp());
}

class EleveurApp extends StatelessWidget {
  const EleveurApp({super.key});
  static final LangController _lang = LangController();

  @override
  Widget build(BuildContext context) {
    // LangScope : toute l'app se reconstruit quand la langue change.
    return LangScope(
      controller: _lang,
      child: Builder(builder: (context) {
        final isAr = LangScope.of(context).isAr;
        return MaterialApp(
          title: 'Mangeoire',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          navigatorKey: navigatorKey,
          routes: AppRoutes.staticRoutes,
          onGenerateRoute: AppRoutes.onGenerateRoute,
          // Arabe = écriture de droite à gauche
          builder: (context, child) => Directionality(
            textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
            child: ValueListenableBuilder<bool>(
              valueListenable: ApiClient.instance.isServerWakingUp,
              builder: (context, wakingUp, _) => Stack(
                fit: StackFit.expand,
                children: [
                  child!,
                  if (wakingUp)
                    PositionedDirectional(
                      top: 0,
                      start: 0,
                      end: 0,
                      child: SafeArea(
                        bottom: false,
                        child: Material(
                          color: AppTheme.primary,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              context.tr('server_waking_up'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          initialRoute: AppRoutes.startup,
        );
      }),
    );
  }
}
