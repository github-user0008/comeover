import 'package:comeover/ui/aurora_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget frame({required Alignment alignment}) => Container(
    color: const Color(0xFFFFFFFF),
    child: PageFrame(
      padding: EdgeInsets.zero,
      alignment: alignment,
      child: Container(
        key: contentKey,
        width: 200,
        height: 60,
        color: const Color(0xFF1A1A1A),
      ),
    ),
  );

  testWidgets('TV navigation insets content away from the bezels', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1280, 720);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(1280, 720),
          navigationMode: NavigationMode.directional,
        ),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: frame(alignment: Alignment.bottomLeft),
        ),
      ),
    );
    final topLeft = tester.getTopLeft(find.byKey(contentKey));
    final bottomRight = tester.getBottomRight(find.byKey(contentKey));
    expect(topLeft.dx, 42.0, reason: 'left overscan margin');
    expect(720 - bottomRight.dy, 48.0, reason: 'bottom overscan margin');
  });

  testWidgets('touch screens keep content edge-to-edge', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1280, 720);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(1280, 720)),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: frame(alignment: Alignment.bottomLeft),
        ),
      ),
    );
    final topLeft = tester.getTopLeft(find.byKey(contentKey));
    final bottomRight = tester.getBottomRight(find.byKey(contentKey));
    expect(topLeft.dx, 0.0);
    expect(720 - bottomRight.dy, 0.0);
  });
}

const contentKey = ValueKey('page-content');
