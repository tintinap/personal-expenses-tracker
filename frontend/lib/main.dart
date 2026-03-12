import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app.dart';
import 'data/database/database_service.dart';
import 'providers/expense_provider.dart';
import 'providers/settings_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables for PostgreSQL connection
  await dotenv.load(fileName: ".env");

  // Initialize PostgreSQL database connection
  await DatabaseService().init();

  runApp(const DailySpendApp());
}

class DailySpendApp extends StatelessWidget {
  const DailySpendApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ExpenseProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
      ],
      child: const App(),
    );
  }
}
