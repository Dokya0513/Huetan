import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../providers/providers.dart';
import '../services/dictionary_service.dart';
import '../widgets/tag_input.dart';

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
  late final TextEditingController _partOfSpeechController;

  String? _audioUrl;
  bool _isLookingUp = false;
  List<String> _tags = [];

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _englishController = TextEditingController(text: existing?.english ?? '');
    _japaneseController = TextEditingController(text: existing?.japanese ?? '');
    _exampleController =
        TextEditingController(text: existing?.exampleSentence ?? '');
    _partOfSpeechController =
        TextEditingController(text: existing?.partOfSpeech ?? '');
    _audioUrl = existing?.audioUrl;
    if (existing != null) {
      ref.read(tagRepositoryProvider).getTagsForWord(existing.id).then((
        tags,
      ) {
        if (mounted) setState(() => _tags = tags);
      });
    }
  }

  @override
  void dispose() {
    _englishController.dispose();
    _japaneseController.dispose();
    _exampleController.dispose();
    _partOfSpeechController.dispose();
    super.dispose();
  }

  Future<void> _lookupDictionary() async {
    final word = _englishController.text.trim();
    if (word.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('先に英単語を入力してください')),
      );
      return;
    }

    setState(() => _isLookingUp = true);
    final result = await _dictionaryService.lookup(word);
    if (!mounted) return;
    setState(() => _isLookingUp = false);

    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('辞書から情報を取得できませんでした')),
      );
      return;
    }

    setState(() {
      if (_partOfSpeechController.text.trim().isEmpty &&
          result.partOfSpeech != null) {
        _partOfSpeechController.text = result.partOfSpeech!;
      }
      if (_exampleController.text.trim().isEmpty && result.example != null) {
        _exampleController.text = result.example!;
      }
      if (result.audioUrl != null) {
        _audioUrl = result.audioUrl;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final repository = ref.read(wordRepositoryProvider);
    final existing = widget.existing;
    final english = _englishController.text.trim();
    final japanese = _emptyToNull(_japaneseController.text);
    final example = _emptyToNull(_exampleController.text);
    final partOfSpeech = _emptyToNull(_partOfSpeechController.text);
    final tagRepository = ref.read(tagRepositoryProvider);

    final int wordId;
    if (existing == null) {
      wordId = await repository.addWord(
        english: english,
        japanese: japanese,
        exampleSentence: example,
        partOfSpeech: partOfSpeech,
        audioUrl: _audioUrl,
      );
    } else {
      wordId = existing.id;
      await repository.updateWord(
        id: existing.id,
        english: english,
        japanese: japanese,
        exampleSentence: example,
        partOfSpeech: partOfSpeech,
        audioUrl: _audioUrl,
      );
    }
    await tagRepository.setTagsForWord(wordId, _tags);

    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final existing = widget.existing;
    if (existing == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('削除確認'),
        content: Text('「${existing.english}」を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('削除'),
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

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? '単語を編集' : '単語を追加'),
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
                    decoration:
                        const InputDecoration(labelText: '英単語 / フレーズ'),
                    validator: (value) => (value == null || value.trim().isEmpty)
                        ? '必須です'
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
                          tooltip: '辞書から自動取得（品詞・例文・発音）',
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
                      ref.read(pronunciationServiceProvider).speak(
                        english,
                        audioUrl: _audioUrl,
                        volume: ref.read(voiceVolumeProvider),
                      );
                    },
                    tooltip: '発音を再生',
                    icon: const Icon(Icons.volume_up_outlined),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _japaneseController,
              decoration: const InputDecoration(
                labelText: '意味（日本語・後から入力してもOK）',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _exampleController,
              decoration: const InputDecoration(labelText: '出てきた例文（任意）'),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _partOfSpeechController,
              decoration: const InputDecoration(labelText: '品詞（任意）'),
            ),
            const SizedBox(height: 12),
            Consumer(
              builder: (context, ref, _) {
                final suggestions =
                    ref.watch(allTagNamesProvider).value ?? [];
                return TagInput(
                  tags: _tags,
                  suggestions: suggestions,
                  onChanged: (tags) => setState(() => _tags = tags),
                );
              },
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _save,
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }
}
