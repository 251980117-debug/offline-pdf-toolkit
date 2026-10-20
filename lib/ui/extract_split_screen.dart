import 'package:flutter/material.dart';

import '../app/app_services.dart';
import '../app/document_opener.dart';
import '../core/output_namer.dart';
import '../core/page_operations.dart';
import '../core/page_plan.dart';
import '../core/page_range_parser.dart';
import '../core/plan_exception.dart';
import '../engine/processing_service.dart';
import 'job_runner.dart';
import 'result_screen.dart';
import 'save_flow.dart';
import 'widgets/page_thumbnail.dart';

enum PageToolMode { extract, split }

enum SplitMethod { everyN, ranges }

class ExtractSplitScreen extends StatefulWidget {
  const ExtractSplitScreen({super.key, required this.mode});

  final PageToolMode mode;

  @override
  State<ExtractSplitScreen> createState() => _ExtractSplitScreenState();
}

class _ExtractSplitScreenState extends State<ExtractSplitScreen> {
  final TextEditingController _ranges = TextEditingController();
  PickedPdf? _picked;
  SplitMethod _method = SplitMethod.everyN;
  int _pagesPerFile = 1;

  bool get _isSplit => widget.mode == PageToolMode.split;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _pick());
  }

  @override
  void dispose() {
    _picked?.document.close();
    _ranges.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final picked = await DocumentOpener.pickPdfs(context, multiple: false);
    if (!mounted) {
      for (final item in picked) {
        await item.document.close();
      }
      return;
    }
    if (picked.isEmpty) {
      Navigator.pop(context);
      return;
    }
    setState(() => _picked = picked.first);
  }

  /// The plans to write, or the reason the input is not valid yet.
  ({List<PagePlan>? plans, String? error}) _evaluate() {
    final source = _picked!.document;
    final doc = SourceDocument(id: source.id, pageCount: source.pageSizes.length);
    try {
      if (!_isSplit) {
        if (_ranges.text.trim().isEmpty) return (plans: null, error: null);
        return (
          plans: [PageOperations.extract(doc, PageRangeParser.parse(_ranges.text, pageCount: doc.pageCount))],
          error: null
        );
      }
      if (_method == SplitMethod.everyN) {
        return (plans: PageOperations.splitEvery(doc, _pagesPerFile), error: null);
      }
      if (_ranges.text.trim().isEmpty) return (plans: null, error: null);
      return (
        plans: PageOperations.splitByGroups(
            doc, PageRangeParser.parseGroups(_ranges.text, pageCount: doc.pageCount)),
        error: null
      );
    } on PlanException catch (e) {
      return (plans: null, error: e.message);
    }
  }

  String _summary(List<PagePlan> plans) {
    String pages(PagePlan plan) => PageRangeParser.format(plan.pages.map((r) => r.pageIndex));
    if (!_isSplit) {
      return 'New PDF with ${plans.first.length} page${plans.first.length == 1 ? '' : 's'}: '
          '${pages(plans.first)}';
    }
    final shown = plans.take(4).map(pages).join(' | ');
    return 'Creates ${plans.length} files: $shown${plans.length > 4 ? ' | ...' : ''}';
  }

  Future<void> _save(List<PagePlan> plans) async {
    final picked = _picked!;
    final processing = AppServices.instance.processing;
    final outputs = AppServices.instance.outputs;
    final base = picked.document.displayName;
    final List<String> names;
    if (_isSplit) {
      names = OutputNamer.uniqueSeries(
          baseName: base, count: plans.length, isTaken: outputs.takenChecker());
    } else {
      final file = await chooseDestination(context, baseName: base, label: 'extracted');
      if (file == null) return;
      names = [file.uri.pathSegments.last];
    }
    if (!mounted) return;
    final results = await JobRunner.run(
      context,
      label: _isSplit ? 'Splitting your PDF' : 'Creating your PDF',
      job: (token, allowUnprotect) async {
        final written = <WriteResult>[];
        try {
          for (var i = 0; i < plans.length; i++) {
            written.add(await processing.writePlan(
              plan: plans[i],
              sources: {picked.document.id: picked.document},
              destination: outputs.fileFor(names[i]),
              sourcePaths: [picked.path],
              allowRemovingPasswordProtection: allowUnprotect,
              cancellation: token,
            ));
          }
          return written;
        } catch (_) {
          // All or nothing: remove parts already written in this job.
          for (final result in written) {
            if (await result.file.exists()) await result.file.delete();
          }
          rethrow;
        }
      },
    );
    if (results == null || !mounted) return;
    await Navigator.pushReplacement(context,
        MaterialPageRoute(builder: (_) => ResultScreen(files: [for (final r in results) r.file])));
  }

  @override
  Widget build(BuildContext context) {
    final picked = _picked;
    return Scaffold(
      appBar: AppBar(title: Text(_isSplit ? 'Split PDF' : 'Extract pages')),
      body: picked == null ? const Center(child: CircularProgressIndicator()) : _body(picked),
    );
  }

  Widget _body(PickedPdf picked) {
    final doc = picked.document;
    final count = doc.pageSizes.length;
    final evaluation = _evaluate();
    final plans = evaluation.plans;
    final text = Theme.of(context).textTheme;
    final showRanges = !_isSplit || _method == SplitMethod.ranges;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(doc.displayName, style: text.titleMedium),
        Text('$count page${count == 1 ? '' : 's'}', style: text.bodyMedium),
        const SizedBox(height: 12),
        SizedBox(
          height: 110,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: count,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) => Column(
              children: [
                PageThumbnail(document: doc, pageIndex: i, size: 84),
                Text('${i + 1}', style: text.labelSmall),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (_isSplit) ...[
          SegmentedButton<SplitMethod>(
            segments: const [
              ButtonSegment(value: SplitMethod.everyN, label: Text('Every N pages')),
              ButtonSegment(value: SplitMethod.ranges, label: Text('By ranges')),
            ],
            selected: {_method},
            onSelectionChanged: (value) => setState(() => _method = value.first),
          ),
          const SizedBox(height: 16),
        ],
        if (_isSplit && _method == SplitMethod.everyN)
          Row(
            children: [
              IconButton.outlined(
                icon: const Icon(Icons.remove),
                onPressed: _pagesPerFile > 1 ? () => setState(() => _pagesPerFile--) : null,
              ),
              Expanded(
                child: Text('$_pagesPerFile page${_pagesPerFile == 1 ? '' : 's'} per file',
                    textAlign: TextAlign.center, style: text.titleMedium),
              ),
              IconButton.outlined(
                icon: const Icon(Icons.add),
                onPressed: _pagesPerFile < count - 1 ? () => setState(() => _pagesPerFile++) : null,
              ),
            ],
          ),
        if (showRanges)
          TextField(
            controller: _ranges,
            keyboardType: TextInputType.text,
            decoration: InputDecoration(
              labelText: _isSplit ? 'Page ranges, one file each' : 'Pages to extract',
              hintText: _isSplit ? 'For example: 1-3, 4-6, 7' : 'For example: 1-3, 5',
              errorText: evaluation.error,
            ),
            onChanged: (_) => setState(() {}),
          ),
        const SizedBox(height: 16),
        if (plans != null) Text(_summary(plans), style: text.bodyMedium),
        const SizedBox(height: 24),
        FilledButton.icon(
          icon: const Icon(Icons.save_outlined),
          label: Text(_isSplit ? 'Split and save' : 'Save as new PDF'),
          onPressed: plans == null ? null : () => _save(plans),
        ),
        const SizedBox(height: 8),
        Text('Your original file is not changed.', style: text.bodySmall, textAlign: TextAlign.center),
      ],
    );
  }
}
