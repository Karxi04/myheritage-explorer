import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myheritage_explorer/core/explorer_ui.dart';

void main() {
  group('BUG 1 — ListTile / DecoratedBox Assertion Fix in ExplorerCard', () {
    testWidgets(
      'ExplorerCard with ListTile (zero contentPadding, selection color, and onTap toggle) renders without assertion',
      (tester) async {
        bool toggleValue = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ExplorerCard(
                child: StatefulBuilder(
                  builder: (context, setState) {
                    return SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Auto-flag profanity'),
                      value: toggleValue,
                      onChanged: (val) {
                        setState(() {
                          toggleValue = val;
                        });
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        );

        expect(find.text('Auto-flag profanity'), findsOneWidget);
        expect(find.byType(SwitchListTile), findsOneWidget);
        expect(find.byType(ListTile), findsOneWidget);

        await tester.tap(find.byType(SwitchListTile));
        await tester.pumpAndSettle();

        expect(toggleValue, isTrue);
      },
    );

    testWidgets(
      'ExplorerCard with explicit background, radius, shadow, and standard ListTile renders and taps cleanly',
      (tester) async {
        bool tapped = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ExplorerCard(
                backgroundColor: Colors.white,
                radius: 14,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(child: Text('A')),
                  title: const Text('Administrator Account'),
                  subtitle: const Text('admin@myheritage.com'),
                  onTap: () {
                    tapped = true;
                  },
                ),
              ),
            ),
          ),
        );

        expect(find.text('Administrator Account'), findsOneWidget);
        await tester.tap(find.byType(ListTile));
        await tester.pumpAndSettle();
        expect(tapped, isTrue);
      },
    );

    testWidgets(
      'ExplorerCard with card-level onTap provides Material InkWell ripple without wrapping DecoratedBox conflict',
      (tester) async {
        bool cardTapped = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ExplorerCard(
                onTap: () => cardTapped = true,
                child: const Text('Clickable Card Content'),
              ),
            ),
          ),
        );

        expect(find.text('Clickable Card Content'), findsOneWidget);
        await tester.tap(find.text('Clickable Card Content'));
        await tester.pumpAndSettle();
        expect(cardTapped, isTrue);
      },
    );
  });

  group('BUG 2 — Admin Review Toolbar Responsive Layout (Wrap / Spacer)', () {
    Widget buildToolbar({
      required TextEditingController searchController,
      required String filter,
      required ValueChanged<String> onFilterChanged,
      required VoidCallback onSync,
      int queueCount = 5,
    }) {
      return ExplorerCard(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 980;
            final textScaler = MediaQuery.textScalerOf(context);
            final scale = textScaler.scale(1.0);
            final effectiveSearchWidth = isWide
                ? 360.0
                : (360.0 * scale).clamp(240.0, constraints.maxWidth);
            final effectiveDropdownWidth = isWide
                ? (210.0 * scale).clamp(210.0, constraints.maxWidth)
                : (210.0 * scale).clamp(210.0, constraints.maxWidth);

            final searchField = ExplorerSearchField(
              controller: searchController,
              hintText: 'Search review, place or user...',
              width: effectiveSearchWidth,
            );

            final filterDropdown = SizedBox(
              width: effectiveDropdownWidth,
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: filter,
                decoration: const InputDecoration(
                  labelText: 'Moderation status',
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(value: 'flagged', child: Text('Flagged')),
                  DropdownMenuItem(value: 'all', child: Text('All')),
                ],
                onChanged: (v) => onFilterChanged(v ?? 'all'),
              ),
            );

            final queueBadge = ExplorerStatusBadge(
              label: ' IN QUEUE',
              tone: ExplorerStatusTone.warning,
            );

            final syncButton = FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: ExplorerColors.navy,
              ),
              onPressed: onSync,
              icon: const Icon(Icons.auto_fix_high_rounded, size: 16),
              label: const Text('Sync All Vendor Reviews'),
            );

            if (isWide) {
              return Row(
                children: [
                  searchField,
                  const SizedBox(width: 12),
                  filterDropdown,
                  const SizedBox(width: 12),
                  queueBadge,
                  const Spacer(),
                  syncButton,
                ],
              );
            }

            return Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                searchField,
                filterDropdown,
                queueBadge,
                syncButton,
              ],
            );
          },
        ),
      );
    }

    testWidgets(
      'Renders without ParentDataWidget error on wide screen (1200px) and positions action button at far right',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final controller = TextEditingController();
        String filter = 'all';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(24),
                child: buildToolbar(
                  searchController: controller,
                  filter: filter,
                  onFilterChanged: (v) => filter = v,
                  onSync: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(Row), findsWidgets);
        expect(find.byType(Spacer), findsOneWidget);
        expect(find.text('Sync All Vendor Reviews'), findsOneWidget);

        final searchX = tester.getTopLeft(find.byType(ExplorerSearchField)).dx;
        final buttonX = tester.getTopLeft(find.text('Sync All Vendor Reviews')).dx;
        expect(buttonX, greaterThan(searchX + 360));
      },
    );

    testWidgets(
      'Renders without ParentDataWidget or overflow error on compact screen (390px)',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final controller = TextEditingController();
        String filter = 'all';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: buildToolbar(
                  searchController: controller,
                  filter: filter,
                  onFilterChanged: (v) => filter = v,
                  onSync: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(Wrap), findsOneWidget);
        expect(find.byType(Spacer), findsNothing);
        expect(find.text('Sync All Vendor Reviews'), findsOneWidget);
        final err = tester.takeException();
if (err is FlutterError) {
  for (final line in err.diagnostics) {
    print('DIAG: ' + line.toString());
  }
}
expect(err, isNull);
      },
    );

    testWidgets(
      'Renders without overflow or ParentDataWidget error with 200% text scale',
      (tester) async {
        tester.view.physicalSize = const Size(600, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final controller = TextEditingController();
        String filter = 'all';

        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                textScaler: TextScaler.linear(2.0),
              ),
              child: Scaffold(
                body: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: buildToolbar(
                    searchController: controller,
                    filter: filter,
                    onFilterChanged: (v) => filter = v,
                    onSync: () {},
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Sync All Vendor Reviews'), findsOneWidget);
        final err = tester.takeException();
if (err is FlutterError) {
  for (final line in err.diagnostics) {
    print('DIAG: ' + line.toString());
  }
}
expect(err, isNull);
      },
    );
  });
}
