import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../l10n/app_localizations.dart';
import '../models/part_of_speech.dart';
import '../providers/providers.dart';
import '../services/dictionary_service.dart';

class WordFormScreen extends ConsumerStatefulWidget {
  final Word? existing;
  const WordFormScreen({super.key, this.existing});

  @override
  ConsumerState<WordFormScreen> createState() => _WordFormScreenState();
}

class _WordFormScreenState extends ConsumerState<WordFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _dictionaryService = DictionaryService();
  late final TextEditingController _englishController;
  late final TextEditingController _japaneseController;
  late final TextEditingController _exampleController;

  PartOfSpeech? _selectedPos;
  String? _audioUrl;
  bool _isLookingUp = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _englishController = TextEditingController(text: existing?.english ?? '');
    _japaneseController = TextEditingController(text: existing?.japanese ?? '');
    _exampleController = TextEditingController(
      text: existing?.exampleSentence ?? '',
    );
    _selectedPos = existing?.partOfSpeech != null
        ? mapToPartOfSpeech(existing!.partOfSpeech!)
        : null;
    _audioUrl = existing?.audioUrl;
  }

  @override
  void dispose() {
    _englishController.dispose();
    _japaneseController.dispose();
    _exampleController.dispose();
    super.dispose();
  }

  Future<void> _lookupDictionary() async {
    final l10n = AppLocalizations.of(context)!;
    final word = _englishController.text.trim();
    if (word.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.enterEnglishFirst)));
      return;
    }

    setState(() => _isLookingUp = true);
    final result = await _dictionaryService.lookup(word);
    if (!mounted) return;
    setState(() => _isLookingUp = false);

    if (result == null || result.senses.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.dictionaryLookupFailed)));
      return;
    }

    if (result.audioUrl != null) {
      setState(() => _audioUrl = result.audioUrl);
    }

    if (result.senses.length == 1) {
      final sense = result.senses.first;
      setState(() {
        _selectedPos ??= sense.partOfSpeech;
        if (_exampleController.text.trim().isEmpty && sense.example != null) {
          _exampleController.text = sense.example!;
        }
      });
      return;
    }

    if (!mounted) return;
    await _pickSense(result.senses);
  }

  Future<void> _pickSense(List<DictionarySense> senses) async {
    final l10n = AppLocalizations.of(context)!;
    final chosen = await showModalBottomSheet<DictionarySense>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                l10n.multipleSensesPrompt,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            ...senses.map(
              (sense) => ListTile(
                title: Text(sense.partOfSpeech.label),
                subtitle: sense.example != null ? Text(sense.example!) : null,
                onTap: () => Navigator.of(context).pop(sense),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (chosen == null || !mounted) return;
    setState(() {
      _selectedPos = chosen.partOfSpeech;
      if (chosen.example != null) {
        _exampleController.text = chosen.example!;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context)!;

    final repository = ref.read(wordRepositoryProvider);
    final existing = widget.existing;
    final english = _englishController.text.trim();
    final japanese = _emptyToNull(_japaneseController.text);
    final example = _emptyToNull(_exampleController.text);
    final partOfSpeech = _selectedPos?.label;

    final duplicate = await repository.findExactDuplicate(
      english: english,
      japanese: japanese,
      partOfSpeech: partOfSpeech,
      excludingId: existing?.id,
    );
    if (duplicate != null) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.alreadyRegisteredTitle),
          content: Text(
            l10n.alreadyRegisteredContent(
              english,
              partOfSpeech ?? l10n.posUnset,
              japanese ?? l10n.translationUnset,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.ok),
            ),
          ],
        ),
      );
      return;
    }

    if (existing == null) {
      await repository.addWord(
        english: english,
        japanese: japanese,
        exampleSentence: example,
        partOfSpeech: partOfSpeech,
        audioUrl: _audioUrl,
      );
    } else {
      await repository.updateWord(
        id: existing.id,
        english: english,
        japanese: japanese,
        exampleSentence: example,
        partOfSpeech: partOfSpeech,
        audioUrl: _audioUrl,
      );
    }

    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final existing = widget.existing;
    if (existing == null) return;
    final l10n = AppLocalizations.of(context)!;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteConfirmTitle),
        content: Text(l10n.deleteConfirmContent(existing.english)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(wordRepositoryProvider).deleteWord(existing.id);
      if (mounted) Navigator.of(context).pop();
    }
  }

  String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? l10n.editWordTitle : l10n.addWordTitle),
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _englishController,
                    decoration: InputDecoration(
                      labelText: l10n.englishFieldLabel,
                    ),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                        ? l10n.requiredField
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: _isLookingUp
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton.filledTonal(
                          onPressed: _lookupDictionary,
                          tooltip: l10n.dictionaryLookupTooltip,
                          icon: const Icon(Icons.auto_fix_high),
                        ),
                ),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: IconButton(
                    onPressed: () {
                      final english = _englishController.text.trim();
                      if (english.isEmpty) return;
                      ref
                          .read(pronunciationServiceProvider)
                          .speak(
                            english,
                            audioUrl: _audioUrl,
                            volume: ref.read(voiceVolumeProvider),
                          );
                    },
                    tooltip: l10n.playPronunciationTooltip,
                    icon: const Icon(Icons.volume_up_outlined),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _japaneseController,
              decoration: InputDecoration(labelText: l10n.japaneseFieldLabel),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _exampleController,
              decoration: InputDecoration(labelText: l10n.exampleFieldLabel),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<PartOfSpeech>(
              initialValue: _selectedPos,
              decoration: InputDecoration(labelText: l10n.posFieldLabel),
              items: PartOfSpeech.values
                  .map(
                    (pos) =>
                        DropdownMenuItem(value: pos, child: Text(pos.label)),
                  )
                  .toList(),
              onChanged: (pos) => setState(() => _selectedPos = pos),
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: _save, child: Text(l10n.save)),
          ],
        ),
      ),
    );
  }
}
