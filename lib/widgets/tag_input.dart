import 'package:flutter/material.dart';

/// Chip-based multi-tag editor with autocomplete suggestions drawn from
/// tags already used elsewhere, to keep genre labels consistent.
class TagInput extends StatelessWidget {
  final List<String> tags;
  final List<String> suggestions;
  final ValueChanged<List<String>> onChanged;

  const TagInput({
    super.key,
    required this.tags,
    required this.suggestions,
    required this.onChanged,
  });

  void _addTag(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty || tags.contains(trimmed)) return;
    onChanged([...tags, trimmed]);
  }

  void _removeTag(String tag) {
    onChanged(tags.where((t) => t != tag).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (tags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tags
                  .map(
                    (tag) => Chip(
                      label: Text(tag),
                      onDeleted: () => _removeTag(tag),
                    ),
                  )
                  .toList(),
            ),
          ),
        Autocomplete<String>(
          optionsBuilder: (textEditingValue) {
            final query = textEditingValue.text.trim();
            if (query.isEmpty) return const Iterable<String>.empty();
            return suggestions.where(
              (s) =>
                  s.toLowerCase().contains(query.toLowerCase()) &&
                  !tags.contains(s),
            );
          },
          onSelected: (selection) {
            _addTag(selection);
          },
          fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
            return TextField(
              controller: controller,
              focusNode: focusNode,
              decoration: const InputDecoration(
                labelText: 'タグ（任意・複数可）',
                hintText: '入力してEnterで追加',
                isDense: true,
              ),
              onSubmitted: (value) {
                _addTag(value);
                controller.clear();
                onSubmitted();
              },
            );
          },
        ),
      ],
    );
  }
}
