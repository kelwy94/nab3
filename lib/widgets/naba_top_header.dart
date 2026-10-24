import 'package:flutter/material.dart';
import '../theme.dart';
import 'naba_widgets.dart';

/// Page header: large title with an optional subtitle, a back button when the
/// page was pushed, and an optional trailing action.
class NabaTopHeader extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final Widget? trailing;

  const NabaTopHeader({super.key, this.title, this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, canPop ? 8 : 20, 8),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          if (canPop)
            const SizedBox(
                width: 52,
                height: 52,
                child: NabaBackButton(background: Colors.white)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title ?? 'نبع',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: NabaTheme.display(24)),
                if (subtitle != null)
                  Text(subtitle!,
                      style: const TextStyle(
                          color: NabaTheme.textSecondary, fontSize: 13)),
              ],
            ),
          ),
          if (trailing != null) trailing!
        ],
      ),
    );
  }
}
