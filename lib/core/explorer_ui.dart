
import 'package:flutter/material.dart';

class ExplorerColors {
  static const navy = Color(0xFF031F4F);
  static const navyDark = Color(0xFF021638);
  static const navySoft = Color(0xFFEAF0F8);
  static const gold = Color(0xFFF2C565);
  static const goldDark = Color(0xFF8A6513);
  static const goldSoft = Color(0xFFFFF3D5);
  static const background = Color(0xFFF9F9FC);
  static const companionBackground = Color(0xFFF3FAFF);
  static const surface = Colors.white;
  static const text = Color(0xFF101828);
  static const muted = Color(0xFF667085);
  static const border = Color(0xFFE1E5EA);
  static const subtle = Color(0xFFF2F4F7);
  static const success = Color(0xFF17885C);
  static const successSoft = Color(0xFFE8F6EF);
  static const danger = Color(0xFFD92D20);
  static const dangerSoft = Color(0xFFFEECEB);
  static const warning = Color(0xFFE6A700);
  static const warningSoft = Color(0xFFFFF4D6);
}

class ExplorerBrand extends StatelessWidget {
  const ExplorerBrand({
    super.key,
    this.compact = false,
    this.dark = false,
    this.subtitle,
  });

  final bool compact;
  final bool dark;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final foreground = dark ? Colors.white : ExplorerColors.navy;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: compact ? 30 : 38,
          height: compact ? 30 : 38,
          decoration: BoxDecoration(
            color: dark ? Colors.white.withOpacity(.12) : ExplorerColors.navySoft,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(
            Icons.account_balance_outlined,
            color: foreground,
            size: compact ? 20 : 24,
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'MyHeritage Explorer',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: foreground,
                  fontSize: compact ? 17 : 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.35,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: dark ? Colors.white70 : ExplorerColors.muted,
                    fontSize: 11,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class ExplorerPageHeader extends StatelessWidget {
  const ExplorerPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.leading,
    this.compact = false,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget? leading;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, compact ? 10 : 14, 10, compact ? 10 : 14),
      decoration: const BoxDecoration(
        color: ExplorerColors.surface,
        border: Border(bottom: BorderSide(color: ExplorerColors.border)),
      ),
      child: Row(
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: ExplorerColors.navy,
                    fontSize: compact ? 18 : 21,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.25,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      color: ExplorerColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

class ExplorerSectionTitle extends StatelessWidget {
  const ExplorerSectionTitle(
    this.title, {
    super.key,
    this.trailing,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: ExplorerColors.navy,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.2,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    color: ExplorerColors.muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class ExplorerCard extends StatelessWidget {
  const ExplorerCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.backgroundColor = ExplorerColors.surface,
    this.borderColor = ExplorerColors.border,
    this.radius = 14,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color backgroundColor;
  final Color borderColor;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A101828),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: content,
      ),
    );
  }
}

class ExplorerStatusBadge extends StatelessWidget {
  const ExplorerStatusBadge({
    super.key,
    required this.label,
    this.tone = ExplorerStatusTone.neutral,
    this.icon,
  });

  final String label;
  final ExplorerStatusTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (tone) {
      ExplorerStatusTone.success => (ExplorerColors.successSoft, ExplorerColors.success),
      ExplorerStatusTone.warning => (ExplorerColors.warningSoft, ExplorerColors.goldDark),
      ExplorerStatusTone.danger => (ExplorerColors.dangerSoft, ExplorerColors.danger),
      ExplorerStatusTone.navy => (ExplorerColors.navySoft, ExplorerColors.navy),
      ExplorerStatusTone.neutral => (ExplorerColors.subtle, ExplorerColors.muted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: foreground),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: .2,
            ),
          ),
        ],
      ),
    );
  }
}

enum ExplorerStatusTone { neutral, success, warning, danger, navy }

class ExplorerMetricCard extends StatelessWidget {
  const ExplorerMetricCard({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.caption,
    this.compact = false,
  });

  final String label;
  final String value;
  final IconData? icon;
  final String? caption;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return ExplorerCard(
      padding: EdgeInsets.all(compact ? 12 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null)
            Container(
              width: compact ? 32 : 38,
              height: compact ? 32 : 38,
              decoration: BoxDecoration(
                color: ExplorerColors.navySoft,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, color: ExplorerColors.navy, size: compact ? 18 : 21),
            ),
          if (icon != null) SizedBox(height: compact ? 8 : 12),
          Text(
            value,
            style: TextStyle(
              color: ExplorerColors.navy,
              fontSize: compact ? 20 : 26,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: ExplorerColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (caption != null) ...[
            const SizedBox(height: 5),
            Text(
              caption!,
              style: const TextStyle(
                color: ExplorerColors.success,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class ExplorerQuickAction extends StatelessWidget {
  const ExplorerQuickAction({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.gold = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool gold;

  @override
  Widget build(BuildContext context) {
    return ExplorerCard(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: gold ? ExplorerColors.goldSoft : ExplorerColors.navySoft,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: gold ? ExplorerColors.goldDark : ExplorerColors.navy,
              size: 22,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: ExplorerColors.text,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class ExplorerLabeledValue extends StatelessWidget {
  const ExplorerLabeledValue({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.alignEnd = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: ExplorerColors.muted,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: .5,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? ExplorerColors.navy,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class ExplorerEmptyState extends StatelessWidget {
  const ExplorerEmptyState({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Icons.inbox_outlined,
    this.action,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: ExplorerColors.navySoft,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 30, color: ExplorerColors.navy),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: ExplorerColors.navy,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: ExplorerColors.muted),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class ExplorerAdminPageTitle extends StatelessWidget {
  const ExplorerAdminPageTitle({
    super.key,
    required this.title,
    required this.subtitle,
    this.actions = const [],
  });

  final String title;
  final String subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final titleContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: ExplorerColors.navy,
            fontSize: 27,
            fontWeight: FontWeight.w800,
            letterSpacing: -.4,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(color: ExplorerColors.muted),
        ),
      ],
    );

    if (actions.isEmpty) return titleContent;

    // Action lists in existing pages contain SizedBox separators. Wrap
    // already provides spacing, so remove those separators here.
    final actionWidgets = actions
        .where((action) => action is! SizedBox)
        .toList(growable: false);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;

        final actionWrap = Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment:
              compact ? WrapAlignment.start : WrapAlignment.end,
          children: actionWidgets,
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titleContent,
              const SizedBox(height: 14),
              actionWrap,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: titleContent),
            const SizedBox(width: 16),
            Flexible(
              child: Align(
                alignment: Alignment.centerRight,
                child: actionWrap,
              ),
            ),
          ],
        );
      },
    );
  }
}

class ExplorerSearchField extends StatelessWidget {
  const ExplorerSearchField({
    super.key,
    this.controller,
    this.hintText = 'Search...',
    this.onChanged,
    this.width,
  });

  final TextEditingController? controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: const Icon(Icons.search, size: 20),
          isDense: true,
        ),
      ),
    );
  }
}
