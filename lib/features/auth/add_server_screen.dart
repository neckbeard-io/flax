import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flax/core/providers/locale_provider.dart';
import 'package:flax/core/providers/server_provider.dart';
import 'package:flax/l10n/app_localizations.dart';
import 'package:flax/shared/widgets/flax_input.dart';
import 'package:flax/shared/widgets/flax_logo.dart';

class AddServerScreen extends ConsumerStatefulWidget {
  const AddServerScreen({super.key});

  @override
  ConsumerState<AddServerScreen> createState() => _AddServerScreenState();
}

class _AddServerScreenState extends ConsumerState<AddServerScreen> {
  final _formKey = GlobalKey<FormState>();
  // Empty, with the suggestion as a hint. Pre-filling it meant clearing
  // someone else's text before typing your own, and a filled field also looks
  // like a value you already confirmed.
  final _nameController = TextEditingController();
  final _urlController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await ref
          .read(serverListProvider.notifier)
          .addServer(
            name: _nameController.text.trim(),
            url: _urlController.text.trim(),
            username: _usernameController.text.trim(),
            password: _passwordController.text,
          );
      if (mounted) context.go('/albums');
    } catch (e) {
      final msg = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      setState(() => _error = msg);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final selectedLocale = ref.watch(localeProvider);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: FlaxLogo(size: 64)),
                  const SizedBox(height: 16),
                  Text(
                    l10n?.appName ?? 'Flax',
                    style: theme.textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n?.connectToMusicServer ??
                        'Connect to your music server',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  // Language selection picker directly on setup screen
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHigh
                            .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant.withValues(
                            alpha: 0.5,
                          ),
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          value: selectedLocale?.languageCode,
                          icon: const Icon(Icons.arrow_drop_down, size: 20),
                          isDense: true,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w500,
                          ),
                          hint: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.language, size: 16),
                              const SizedBox(width: 6),
                              Text(l10n?.systemDefault ?? 'System Default'),
                            ],
                          ),
                          items: kSupportedLanguageOptions.map((opt) {
                            return DropdownMenuItem<String?>(
                              value: opt.code,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.language, size: 16),
                                  const SizedBox(width: 6),
                                  Text(
                                    opt.code == null
                                        ? (l10n?.systemDefault ??
                                              'System Default')
                                        : opt.nativeName,
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (code) {
                            ref
                                .read(localeProvider.notifier)
                                .setLocale(code != null ? Locale(code) : null);
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _nameController,
                    decoration: flaxInputDecoration(
                      context,
                      hintText: l10n?.serverNameHint ?? 'My Server',
                      prefixIcon: const Icon(Icons.label_outline),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? (l10n?.required ?? 'Required')
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _urlController,
                    decoration: flaxInputDecoration(
                      context,
                      hintText:
                          l10n?.serverUrlHint ?? 'https://music.example.com',
                      prefixIcon: const Icon(Icons.dns_outlined),
                    ),
                    keyboardType: TextInputType.url,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return l10n?.required ?? 'Required';
                      }
                      final uri = Uri.tryParse(v.trim());
                      if (uri == null || !uri.hasScheme) {
                        return l10n?.enterValidUrl ??
                            'Enter a valid URL with http(s)://';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _usernameController,
                    decoration: flaxInputDecoration(
                      context,
                      hintText: l10n?.username ?? 'Username',
                      prefixIcon: const Icon(Icons.person_outline),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? (l10n?.required ?? 'Required')
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    decoration: flaxInputDecoration(
                      context,
                      hintText: l10n?.password ?? 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                    ),
                    obscureText: true,
                    textInputAction: TextInputAction.go,
                    onFieldSubmitted: (_) => _loading ? null : _submit(),
                    validator: (v) => v == null || v.isEmpty
                        ? (l10n?.required ?? 'Required')
                        : null,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      style: TextStyle(color: theme.colorScheme.error),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n?.connect ?? 'Connect'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
