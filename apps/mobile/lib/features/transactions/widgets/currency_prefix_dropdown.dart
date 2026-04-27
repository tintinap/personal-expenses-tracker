import 'package:flutter/material.dart';
import '../../../../core/currency_helper.dart';

class CurrencyPrefixDropdown extends StatelessWidget {
  final String selectedCurrency;
  final ValueChanged<String> onChanged;

  const CurrencyPrefixDropdown({
    super.key,
    required this.selectedCurrency,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _showCurrencyPicker(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              selectedCurrency,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Container(
              width: 1,
              height: 24,
              color: Theme.of(context).dividerColor,
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  void _showCurrencyPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Select Currency',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: CurrencyCode.values.length,
                  itemBuilder: (context, index) {
                    final curr = CurrencyCode.values[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                        child: Text(curr.symbol, style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                      ),
                      title: Text(curr.code),
                      subtitle: Text(curr.name),
                      trailing: curr.code == selectedCurrency
                          ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                          : null,
                      onTap: () {
                        onChanged(curr.code);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
