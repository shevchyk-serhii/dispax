import 'package:flutter/material.dart';

import '../helpers/tag_helpers.dart';

/// Reusable free-form tag editor: a wrap of deletable [InputChip]s for the
/// current tags, a text field to add new ones, and an optional row of
/// suggestion chips (previously-used tags). Stateless about storage — the
/// parent owns the [tags] list and reacts to [onAdded] / [onRemoved], so the
/// same widget serves both the create form (BLoC) and the edit dialog (setState).
class TagInputField extends StatefulWidget {
  final List<String> tags;

  /// Previously-used tags offered as quick-add chips (already-selected ones are
  /// hidden). Pass an empty list to omit the suggestion row.
  final List<String> suggestions;
  final ValueChanged<String> onAdded;
  final ValueChanged<String> onRemoved;
  final String label;

  const TagInputField({
    super.key,
    required this.tags,
    required this.onAdded,
    required this.onRemoved,
    this.suggestions = const [],
    this.label = 'Tags',
  });

  @override
  State<TagInputField> createState() => _TagInputFieldState();
}

class _TagInputFieldState extends State<TagInputField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = normalizeTag(_controller.text);
    if (value.isEmpty) return;
    widget.onAdded(value);
    _controller.clear();
  }

  bool _alreadySelected(String tag) =>
      widget.tags.any((t) => t.toLowerCase() == tag.toLowerCase());

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final freshSuggestions = widget.suggestions
        .where((s) => !_alreadySelected(s))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        if (widget.tags.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.tags
                .map(
                  (tag) => InputChip(
                    key: ValueKey('tag-chip-$tag'),
                    label: Text(tag),
                    onDeleted: () => widget.onRemoved(tag),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    deleteIconColor: colorScheme.onSurfaceVariant,
                  ),
                )
                .toList(),
          ),
        if (widget.tags.isNotEmpty) const SizedBox(height: 8),
        TextField(
          controller: _controller,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            hintText: 'Add a tag…',
            isDense: true,
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Add tag',
              onPressed: _submit,
            ),
          ),
          onSubmitted: (_) => _submit(),
        ),
        if (freshSuggestions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: freshSuggestions
                .map(
                  (s) => ActionChip(
                    key: ValueKey('tag-suggestion-$s'),
                    avatar: const Icon(Icons.add, size: 16),
                    label: Text(s),
                    onPressed: () => widget.onAdded(s),
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }
}
