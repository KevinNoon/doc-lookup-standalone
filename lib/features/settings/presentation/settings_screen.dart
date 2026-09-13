import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/settings_repository.dart';

final _apiKeyPageUrl = Uri.parse('https://aistudio.google.com/apikey');

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _controller = TextEditingController();
  bool _obscure = true;
  bool _isSaving = false;
  bool _loadedInitial = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openApiKeyPage() async {
    final launched = await launchUrl(_apiKeyPageUrl, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the browser — visit aistudio.google.com/apikey manually.')),
      );
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final key = _controller.text.trim();
      await ref.read(settingsRepositoryProvider.future).then(
            (repo) => repo.setGeminiApiKey(key.isEmpty ? null : key),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(key.isEmpty ? 'API key cleared.' : 'API key saved.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final apiKeyAsync = ref.watch(geminiApiKeyProvider);
    apiKeyAsync.whenData((key) {
      if (!_loadedInitial) {
        _loadedInitial = true;
        _controller.text = key ?? '';
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Gemini API key', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'AI word lookup runs on Google Gemini, using your own free API key — '
              'nothing is billed to anyone else and no account is required beyond a '
              'free Google AI Studio key.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _openApiKeyPage,
              child: Text(
                'aistudio.google.com/apikey',
                style: TextStyle(color: Theme.of(context).colorScheme.primary, decoration: TextDecoration.underline),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _controller,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: 'API key',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
