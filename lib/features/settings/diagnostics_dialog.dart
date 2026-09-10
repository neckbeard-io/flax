import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:flax/services/diagnostics/diagnostics_service.dart';

/// Modal dialog displaying system diagnostics, audio hardware state, server capabilities,
/// and recent sanitized logs with one-click export and GitHub issue creation.
class DiagnosticsDialog extends ConsumerWidget {
  const DiagnosticsDialog({super.key});

  static const String gitHubNewIssueUrl =
      'https://github.com/neckbeard-io/flax/issues/new?title=%5BBug%5D%3A+&labels=needs-triage';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final reportAsync = ref.watch(diagnosticsReportProvider);
    final mediaQuery = MediaQuery.of(context);
    final isMobile = mediaQuery.size.width < 600;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 24,
        vertical: isMobile ? 16 : 24,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 720,
          maxHeight: mediaQuery.size.height * 0.88,
        ),
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header ──
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.bug_report_outlined,
                      color: theme.colorScheme.onPrimaryContainer,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Diagnostics & System Info',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Export sanitized environment metadata & logs for issue reporting',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Content ──
              Expanded(
                child: reportAsync.when(
                  loading: () => const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Gathering system state and runtime logs...'),
                      ],
                    ),
                  ),
                  error: (err, stack) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 40,
                            color: theme.colorScheme.error,
                          ),
                          const SizedBox(height: 8),
                          Text('Failed to collect diagnostics: $err'),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: () =>
                                ref.invalidate(diagnosticsReportProvider),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  data: (report) => _DiagnosticsContent(report: report),
                ),
              ),
              const SizedBox(height: 16),

              // ── Actions ──
              reportAsync.maybeWhen(
                data: (report) => _DiagnosticsActions(report: report),
                orElse: () => Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiagnosticsContent extends StatelessWidget {
  final DiagnosticsReport report;

  const _DiagnosticsContent({required this.report});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sanitizedMarkdown = report.getSanitizedMarkdown();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Summary Overview Badges ──
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Badge(
                icon: Icons.apps,
                label: 'App',
                value:
                    '${report.appVersion} (${report.buildNumber}) · ${report.updateChannel}',
              ),
              _Badge(
                icon: Icons.computer,
                label: 'OS',
                value: '${report.osName} (${report.architecture})',
              ),
              _Badge(
                icon: Icons.headphones,
                label: 'Audio',
                value:
                    '${report.outputDescription} · ${report.sampleRate}/${report.bitDepth}',
              ),
              _Badge(
                icon: Icons.dns_outlined,
                label: 'Server',
                value: report.serverType != null
                    ? '${report.serverType} ${report.serverVersion ?? ""} (API ${report.subsonicApiVersion ?? ""})'
                    : 'No Server',
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Privacy / Redaction Notice ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.shield_outlined,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Sensitive data sanitized: Passwords, tokens, server hostnames, IP addresses, and user home paths have been automatically redacted.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Code Preview Box ──
          Text(
            'Sanitized Markdown Report',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            height: 240,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: SelectableText(
                sanitizedMarkdown,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  fontSize: 11.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _Badge({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Flexible(
            child: Text.rich(
              TextSpan(
                text: '$label: ',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                children: [
                  TextSpan(
                    text: value,
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _DiagnosticsActions extends StatelessWidget {
  final DiagnosticsReport report;

  const _DiagnosticsActions({required this.report});

  Future<void> _copyToClipboard(BuildContext context) async {
    final sanitized = report.getSanitizedMarkdown();
    await Clipboard.setData(ClipboardData(text: sanitized));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Diagnostics report copied to clipboard'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _openGitHubIssue(BuildContext context) async {
    await _copyToClipboard(context);
    final uri = Uri.parse(DiagnosticsDialog.gitHubNewIssueUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        OutlinedButton.icon(
          onPressed: () => _copyToClipboard(context),
          icon: const Icon(Icons.copy, size: 16),
          label: const Text('Copy to Clipboard'),
        ),
        FilledButton.icon(
          onPressed: () => _openGitHubIssue(context),
          icon: const Icon(Icons.open_in_new, size: 16),
          label: const Text('Open GitHub Issue'),
        ),
      ],
    );
  }
}
