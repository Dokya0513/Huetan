import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
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
    _exampleController =
        TextEditingController(text: existing?.exampleSentence ?? '');
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

    if (result == null || result.senses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('辞書から情報を取得できませんでした')),
      );
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
    final chosen = await showModalBottomSheet<DictionarySense>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'この単語には複数の品詞があります。どちらの意味で登録しますか？',
                style: TextStyle(fontWeight: FontWeight.w700),
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
          title: const Text('既に登録されています'),
          content: Text(
            '「$english」（${partOfSpeech ?? "品詞未設定"}・${japanese ?? "意味未設定"}）は既に登録済みです。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
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
            DropdownButtonFormField<PartOfSpeech>(
              initialValue: _selectedPos,
              decoration: const InputDecoration(labelText: '品詞（任意）'),
              items: PartOfSpeech.values
                  .map(
                    (pos) =>
                        DropdownMenuItem(value: pos, child: Text(pos.label)),
                  )
                  .toList(),
              onChanged: (pos) => setState(() => _selectedPos = pos),
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
