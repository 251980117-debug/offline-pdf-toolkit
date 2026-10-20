import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../core/quarter_turn.dart';
import '../../engine/pdf_engine.dart';
import '../../engine/pdfrx_engine.dart';

/// A small, rotated preview of one page.
class PageThumbnail extends StatelessWidget {
  const PageThumbnail({
    super.key,
    required this.document,
    required this.pageIndex,
    this.turn = QuarterTurn.none,
    this.size = 72,
  });

  final OpenedPdf document;
  final int pageIndex;
  final QuarterTurn turn;
  final double size;

  @override
  Widget build(BuildContext context) {
    final page = document.pageSizes[pageIndex].rotated(turn);
    final pdf = PdfrxEngine.pdfrxDocumentOf(document);
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: AspectRatio(
          aspectRatio: page.width / page.height,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: pdf == null
                ? const SizedBox.shrink()
                : RotatedBox(
                    quarterTurns: turn.turns,
                    child: PdfPageView(document: pdf, pageNumber: pageIndex + 1, maximumDpi: 96),
                  ),
          ),
        ),
      ),
    );
  }
}
