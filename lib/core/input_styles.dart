import 'package:material_ui/material_ui.dart';

const appInputTextStyle = TextStyle(
  color: Color(0xFF19191D),
  fontSize: 20,
  fontWeight: FontWeight.w400,
  letterSpacing: 0.44,
  fontFamily: 'NotoSansKhmer',
);

class AppInputFocusGlow extends StatefulWidget {
  const AppInputFocusGlow({required this.child, super.key});

  final Widget child;

  @override
  State<AppInputFocusGlow> createState() => _AppInputFocusGlowState();
}

class _AppInputFocusGlowState extends State<AppInputFocusGlow> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final focusColor = Theme.of(context).colorScheme.primary;
    return Focus(
      onFocusChange: (focused) {
        if (_focused != focused) setState(() => _focused = focused);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          boxShadow: _focused
              ? [
                  BoxShadow(
                    color: focusColor.withValues(alpha: 0.24),
                    blurRadius: 16,
                  ),
                  BoxShadow(
                    color: focusColor.withValues(alpha: 0.48),
                    blurRadius: 4,
                  ),
                ]
              : null,
        ),
        child: widget.child,
      ),
    );
  }
}

class AppDropdownButtonFormField<T> extends StatefulWidget {
  const AppDropdownButtonFormField({
    required this.items,
    required this.onChanged,
    this.initialValue,
    this.hint,
    this.decoration,
    this.isExpanded = true,
    super.key,
  });

  final List<DropdownMenuItem<T>> items;
  final T? initialValue;
  final Widget? hint;
  final InputDecoration? decoration;
  final bool isExpanded;
  final ValueChanged<T?>? onChanged;

  @override
  State<AppDropdownButtonFormField<T>> createState() =>
      _AppDropdownButtonFormFieldState<T>();
}

class _AppDropdownButtonFormFieldState<T>
    extends State<AppDropdownButtonFormField<T>> {
  late T? _selectedValue = widget.initialValue;

  @override
  void didUpdateWidget(AppDropdownButtonFormField<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != oldWidget.initialValue) {
      _selectedValue = widget.initialValue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth =
            constraints.hasBoundedWidth ? constraints.maxWidth : null;
        final items = [
          for (var index = 0; index < widget.items.length; index++)
            _buildMenuItem(
              context,
              widget.items[index],
              width: itemWidth,
              isFirst: index == 0,
              isLast: index == widget.items.length - 1,
            ),
        ];
        return AppInputFocusGlow(
          child: DropdownButtonFormField<T>(
            initialValue: widget.initialValue,
            isExpanded: widget.isExpanded,
            style: appInputTextStyle,
            hint: widget.hint,
            decoration: widget.decoration,
            items: items,
            selectedItemBuilder: (_) =>
                widget.items.map((item) => item.child).toList(growable: false),
            itemHeight: 64,
            menuMaxHeight: 320,
            dropdownColor: widget.decoration?.fillColor ??
                Theme.of(context).inputDecorationTheme.fillColor ??
                Colors.white,
            focusColor: const Color(0xFFEBF2FF),
            borderRadius: BorderRadius.circular(10),
            onChanged: widget.onChanged == null
                ? null
                : (value) {
                    setState(() => _selectedValue = value);
                    widget.onChanged!(value);
                  },
          ),
        );
      },
    );
  }

  DropdownMenuItem<T> _buildMenuItem(
    BuildContext context,
    DropdownMenuItem<T> item, {
    required double? width,
    required bool isFirst,
    required bool isLast,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = item.value == _selectedValue;
    return DropdownMenuItem<T>(
      key: item.key,
      value: item.value,
      enabled: item.enabled,
      onTap: item.onTap,
      alignment: item.alignment,
      child: _AppDropdownMenuItemContent(
        width: width,
        isSelected: isSelected,
        isFirst: isFirst,
        isLast: isLast,
        child: Row(
          children: [
            Expanded(child: item.child),
            if (isSelected)
              Icon(
                Icons.check,
                color: colorScheme.primary,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}

class _AppDropdownMenuItemContent extends StatefulWidget {
  const _AppDropdownMenuItemContent({
    required this.width,
    required this.isSelected,
    required this.isFirst,
    required this.isLast,
    required this.child,
  });

  final double? width;
  final bool isSelected;
  final bool isFirst;
  final bool isLast;
  final Widget child;

  @override
  State<_AppDropdownMenuItemContent> createState() =>
      _AppDropdownMenuItemContentState();
}

class _AppDropdownMenuItemContentState
    extends State<_AppDropdownMenuItemContent> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: SizedBox(
        width: widget.width,
        child: Container(
          height: 64 - (widget.isFirst ? 1 : 0) - (widget.isLast ? 1 : 0),
          margin: EdgeInsets.fromLTRB(
            1,
            widget.isFirst ? 1 : 0,
            1,
            widget.isLast ? 1 : 0,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: widget.isSelected || _hovered
                ? const Color(0xFFEBF2FF)
                : Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
