import 'package:flutter/material.dart';

import '../core/app_theme.dart';

/// A single step in a [SurveyWizard]: a title, an optional subtitle, and
/// the content widget for that step.
class SurveyStep {
  final String title;
  final String? subtitle;
  final Widget content;

  /// Checked before leaving this step (Next or Finish). Return an error
  /// message to block the move and surface it to the user, or null if the
  /// step is complete. Omit for steps with nothing required.
  final String? Function()? validate;

  const SurveyStep({
    required this.title,
    this.subtitle,
    required this.content,
    this.validate,
  });
}

/// Generic paged wizard used to break a long, "hepsi tek sayfada" survey
/// form into a clear step-by-step flow with a progress bar and
/// Back / Next navigation. Each step's content is provided by the caller,
/// so all existing field widgets, controllers and validation logic can be
/// reused unchanged — only the presentation becomes multi-step.
class SurveyWizard extends StatefulWidget {
  final List<SurveyStep> steps;

  /// Called when the user taps the button on the final step.
  /// Return true to allow completion (used e.g. to run validation);
  /// return false to stay on the last step.
  final Future<bool> Function() onFinish;

  final String finishLabel;
  final String nextLabel;
  final String backLabel;

  /// Called whenever the visible step changes (including via swipe-free
  /// Back/Next navigation), so callers can persist a draft of the current
  /// step's data as a safety net beyond just app-lifecycle pauses.
  final ValueChanged<int>? onStepChanged;

  const SurveyWizard({
    super.key,
    required this.steps,
    required this.onFinish,
    this.finishLabel = 'Tamamla',
    this.nextLabel = 'İleri',
    this.backLabel = 'Geri',
    this.onStepChanged,
  });

  @override
  State<SurveyWizard> createState() => _SurveyWizardState();
}

class _SurveyWizardState extends State<SurveyWizard> {
  final PageController _controller = PageController();
  int _index = 0;
  bool _submitting = false;

  bool get _isLastStep => _index == widget.steps.length - 1;

  void _goNext() {
    final error = widget.steps[_index].validate?.call();
    if (error != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    if (_isLastStep) {
      _finish();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _goBack() {
    if (_index == 0) return;
    _controller.previousPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Future<void> _finish() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    final success = await widget.onFinish();
    if (!mounted) return;
    setState(() => _submitting = false);
    // If onFinish returns false (e.g. validation failed), stay put so the
    // user can fix the current step; the caller is responsible for
    // showing the relevant error message.
    if (!success) return;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.steps.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_index + 1} / $total',
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: (_index + 1) / total,
                  minHeight: 6,
                  backgroundColor: Colors.white12,
                  valueColor: const AlwaysStoppedAnimation(
                    AppTheme.brandPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: PageView(
            controller: _controller,
            physics: const NeverScrollableScrollPhysics(),
            onPageChanged: (i) {
              setState(() => _index = i);
              widget.onStepChanged?.call(i);
            },
            children: widget.steps.map((step) {
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (step.subtitle != null) ...[
                      Text(
                        step.subtitle!,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    step.content,
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Row(
            children: [
              if (_index > 0)
                Expanded(
                  child: OutlinedButton(
                    onPressed: _submitting ? null : _goBack,
                    child: Text(widget.backLabel),
                  ),
                ),
              if (_index > 0) const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  key: const ValueKey('survey_wizard_primary_button'),
                  onPressed: _submitting ? null : _goNext,
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          _isLastStep ? widget.finishLabel : widget.nextLabel,
                        ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
