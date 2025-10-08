import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/menu_provider.dart';
import 'providers/order_provider.dart';
import 'screens/start_order_screen.dart';
import 'screens/menu_screen.dart';
import 'screens/order_review_screen.dart';
import 'screens/menu_crud_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MenuProvider()),
        ChangeNotifierProvider(create: (_) => OrderProvider()),
      ],
      child: MaterialApp(
        title: 'LeSon POS',
        theme: ThemeData(
          colorScheme:
              ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        initialRoute: '/',
        routes: {
          '/': (context) => const StartOrderScreen(),
          '/menu': (context) => const MenuScreen(),
          '/review': (context) => const OrderReviewScreen(),
          '/menu-crud': (context) => const MenuCrudScreen(),
        },
      ),
    );
  }
}
