import 'package:flutter/material.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';

/// Текстовое поле формы с маленькой кнопкой быстрой очистки (×) в суффиксе.
///
/// Value-based: синхронизирует внутренний контроллер с внешним [value]
/// (например, при очистке формы, swap адресов, заполнении из шаблона),
/// поэтому подходит для полей, управляемых BLoC через initialValue.
class ClearableTextField extends StatefulWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final String labelText;
  final String? hintText;
  final IconData? prefixIconData;
  final Color? prefixIconColor;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final int maxLines;
  final int minLines;

  const ClearableTextField({
    super.key,
    required this.value,
    required this.onChanged,
    required this.labelText,
    this.hintText,
    this.prefixIconData,
    this.prefixIconColor,
    this.validator,
    this.keyboardType,
    this.maxLines = 1,
    this.minLines = 1,
  });

  @override
  State<ClearableTextField> createState() => _ClearableTextFieldState();
}

class _ClearableTextFieldState extends State<ClearableTextField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    _controller.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(ClearableTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Синхронизация при внешнем изменении value (очистка формы, swap, шаблон),
    // без сброса позиции курсора при обычном вводе.
    if (widget.value != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  void _onTextChanged() {
    // Перерисовать, чтобы показать/скрыть кнопку очистки.
    setState(() {});
  }

  void _clear() {
    _controller.clear();
    widget.onChanged('');
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasText = _controller.text.isNotEmpty;
    return TextFormField(
      controller: _controller,
      keyboardType: widget.keyboardType,
      maxLines: widget.maxLines,
      minLines: widget.minLines,
      decoration: InputDecoration(
        labelText: widget.labelText,
        hintText: widget.hintText,
        prefixIcon: widget.prefixIconData != null
            ? Icon(widget.prefixIconData, color: widget.prefixIconColor)
            : null,
        suffixIcon: hasText
            ? IconButton(
                icon: const Icon(Icons.close, size: 18),
                color: AppColors.textSecondary,
                tooltip: 'Clear',
                splashRadius: 18,
                onPressed: _clear,
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
        ),
      ),
      validator: widget.validator,
      onChanged: widget.onChanged,
    );
  }
}
