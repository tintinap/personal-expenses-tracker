import 'package:flutter_driver/flutter_driver.dart';

void main() async {
  final driver = await FlutterDriver.connect();
  final health = await driver.checkHealth();
  print('Health: \${health.status}');
  
  final txt = await driver.getText(find.byType('Text'));
  print('Found text: \$txt');
  
  await driver.close();
}
