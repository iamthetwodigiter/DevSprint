import 'package:flutter/material.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      clipBehavior: Clip.antiAlias,
      shadowColor: Theme.of(context).highlightColor,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Theme.of(context).hoverColor),
        borderRadius: BorderRadius.circular(15)
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class SectionLabel extends StatelessWidget {
  final String title;
  final String? action;

  const SectionLabel({super.key, required this.title, this.action});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const Spacer(),
        if (action != null)
          Text(action!, style: Theme.of(context).textTheme.labelLarge),
      ],
    );
  }
}
