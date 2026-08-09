import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../l10n/app_localizations.dart';
import '../models/learning_direction.dart';
import '../models/part_of_speech.dart';
import '../providers/providers.dart';
import '../services/dictionary_service.dart';
import '../services/japanese_dictionary_service.dart';

class WordFormScreen extends ConsumerStatefulWidget {
  final Word? existing;
  const WordFormScreen({super.key, this.existing});

  @override
  ConsumerState<WordFormScreen> createState() => _WordFormScreenState();
}

class _WordFormScreenState extends ConsumerState<WordFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _dictionaryService = DictionaryService();
  final _japaneseDictionaryService = JapaneseDictionaryService();
  late final TextEditingController _englishController;
  late final TextEditingController _japaneseController;
  late final TextEditingController _exampleController;

  PartOfSpeech? _selectedPos;
  String? _audioUrl;
  String? _japaneseReading;
  bool _isLookingUp = false;

  // Extra example sentences captured alongside the primary one in
  // _exampleController, and the exact primary text they were captured for —
  // if the user later retypes the primary example by hand, these no longer
  // correspond to it and are dropped at save time rather than saved stale.
  List<String> _extraExamples = [];
  String? _extraExamplesSourceText;

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
    _japaneseReading = existing?.japaneseReading;
    final existingExtras = existing?.extraExamples;
    if (existingExtras != null && existingExtras.isNotEmpty) {
      _extraExamples = (jsonDecode(existingExtras) as List).cast<String>();
      _extraExamplesSourceText = existing?.exampleSentence;
    }
    _japaneseController.addListener(_invalidateReadingOnManualEdit);
  }

  /// The stored reading only applies to the exact text it was looked up
  /// for — if the user edits the Japanese field by hand afterward (rather
  /// than via a fresh lookup), the reading would silently go stale, so
  /// drop it as soon as the text changes non-programmatically.
  void _invalidateReadingOnManualEdit() {
    if (_japaneseReading != null) {
      _japaneseReading = null;
    }
  }

  @override
  void dispose() {
    _japaneseController.removeListener(_invalidateReadingOnManualEdit);
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
      _applySense(result.senses.first, isEnTarget: true, overwritePos: false);
      return;
    }

    if (!mounted) return;
    await _pickSense(result.senses, isEnTarget: true);
  }

  Future<void> _lookupJapaneseDictionary() async {
    final l10n = AppLocalizations.of(context)!;
    final word = _japaneseController.text.trim();
    if (word.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.enterJapaneseFirst)));
      return;
    }

    setState(() => _isLookingUp = true);
    final result = await _japaneseDictionaryService.lookup(word);
    if (!mounted) return;
    setState(() => _isLookingUp = false);

    if (result == null || result.senses.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.dictionaryLookupFailed)));
      return;
    }

    // The reading applies to whatever text was just looked up — captured
    // here rather than left to the field-change listener, since this
    // lookup reads (not writes) the Japanese field.
    if (result.reading != null) {
      _japaneseReading = result.reading;
    }

    if (result.senses.length == 1) {
      _applySense(
        result.senses.first,
        isEnTarget: false,
        overwritePos: false,
      );
      return;
    }

    if (!mounted) return;
    await _pickSense(result.senses, isEnTarget: false);
  }

  /// Fills in the part-of-speech and example/meaning from a dictionary
  /// sense. [overwritePos] is true when the user explicitly picked this
  /// sense from a list (their choice should win), false when it's the only
  /// candidate and was applied automatically (a guess — shouldn't clobber a
  /// part of speech the user already picked by hand). The example/meaning
  /// fields are only filled if still empty either way, so a lookup never
  /// clobbers something the user already typed there.
  void _applySense(
    DictionarySense sense, {
    required bool isEnTarget,
    required bool overwritePos,
  }) {
    setState(() {
      if (overwritePos) {
        _selectedPos = sense.partOfSpeech;
      } else {
        _selectedPos ??= sense.partOfSpeech;
      }
      if (_exampleController.text.trim().isEmpty && sense.examples.isNotEmpty) {
        _exampleController.text = sense.examples.first;
        _extraExamples = sense.examples.skip(1).toList();
        _extraExamplesSourceText = sense.examples.first;
      }
      final meaningController = isEnTarget
          ? _japaneseController
          : _englishController;
      if (meaningController.text.trim().isEmpty && sense.meaning != null) {
        meaningController.text = sense.meaning!;
      }
    });
  }

  Future<void> _pickSense(
    List<DictionarySense> senses, {
    required bool isEnTarget,
  }) async {
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
                title: Text(sense.partOfSpeech.displayLabel(l10n)),
                subtitle: sense.example != null || sense.meaning != null
                    ? Text(sense.meaning ?? sense.example!)
                    : null,
                onTap: () => Navigator.of(context).pop(sense),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (chosen == null || !mounted) return;
    _applySense(chosen, isEnTarget: isEnTarget, overwritePos: true);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context)!;

    final repository = ref.read(wordRepositoryProvider);
    final learningMode = ref.read(learningModeProvider);
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
      learningDirection: learningMode,
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
              _selectedPos?.displayLabel(l10n) ?? l10n.posUnset,
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

    // The reading is only valid if it still matches the current text (the
    // manual-edit listener clears it otherwise).
    final japaneseReading = japanese != null ? _japaneseReading : null;
    // Same idea for the extra examples: only valid if the primary example
    // still matches the text they were captured alongside.
    final extraExamples = (example != null && example == _extraExamplesSourceText)
        ? _extraExamples
        : null;

    if (existing == null) {
      await repository.addWord(
        english: english,
        japanese: japanese,
        exampleSentence: example,
        extraExamples: extraExamples,
        partOfSpeech: partOfSpeech,
        audioUrl: _audioUrl,
        japaneseReading: japaneseReading,
        learningDirection: learningMode,
      );
    } else {
      await repository.updateWord(
        id: existing.id,
        english: english,
        japanese: japanese,
        exampleSentence: example,
        extraExamples: extraExamples,
        partOfSpeech: partOfSpeech,
        audioUrl: _audioUrl,
        japaneseReading: japaneseReading,
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
    final isEnTarget =
        ref.watch(learningModeProvider) == LearningDirection.enTarget;

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
                // Dictionary auto-fill is English-only for now (see
                // dictionary_service.dart) — hidden in Japanese-learning
                // mode until a Japanese equivalent exists.
                if (isEnTarget) ...[
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
                              languageCode: 'en-US',
                            );
                      },
                      tooltip: l10n.playPronunciationTooltip,
                      icon: const Icon(Icons.volume_up_outlined),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _japaneseController,
                    decoration: InputDecoration(
                      labelText: l10n.japaneseFieldLabel,
                    ),
                    // enTarget allows a "quick add" with the meaning filled
                    // in later; jaTarget has no such flow since `english`
                    // (the meaning, in that mode) is a NOT NULL DB column.
                    validator: isEnTarget
                        ? null
                        : (value) => (value == null || value.trim().isEmpty)
                        ? l10n.requiredField
                        : null,
                  ),
                ),
                if (!isEnTarget) ...[
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
                            onPressed: _lookupJapaneseDictionary,
                            tooltip: l10n.dictionaryLookupTooltip,
                            icon: const Icon(Icons.auto_fix_high),
                          ),
                  ),
                  const SizedBox(width: 4),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: IconButton(
                      onPressed: () {
                        final japanese = _japaneseController.text.trim();
                        if (japanese.isEmpty) return;
                        ref
                            .read(pronunciationServiceProvider)
                            .speak(
                              _japaneseReading ?? japanese,
                              volume: ref.read(voiceVolumeProvider),
                              languageCode: 'ja-JP',
                            );
                      },
                      tooltip: l10n.playPronunciationTooltip,
                      icon: const Icon(Icons.volume_up_outlined),
                    ),
                  ),
                ],
              ],
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
                    (pos) => DropdownMenuItem(
                      value: pos,
                      child: Text(pos.displayLabel(l10n)),
                    ),
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
