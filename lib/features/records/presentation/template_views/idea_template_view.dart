// lib/features/records/presentation/template_views/idea_template_view.dart
// Reading view for idea template notes.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:suicun/features/records/domain/record_model.dart';
import 'package:suicun/features/records/presentation/template_views/template_detector.dart';
import 'package:suicun/features/records/presentation/template_views/template_header_card.dart';
import 'package:suicun/features/records/presentation/template_views/updated_at_text.dart';
import 'package:suicun/l10n/generated/app_localizations.dart';

class IdeaTemplateView extends StatefulWidget {
  const IdeaTemplateView({
    super.key,
    required this.data,
    required this.record,
    required this.onEdit,
    required this.categoryRow,
    required this.tagRow,
    this.suggestionRow,
    this.isEditing = false,
    this.titleController,
    this.onTitleChanged,
    this.onBodyChanged,
    this.rawBody,
  });

  final IdeaTemplateData data;
  final RecordDetail? record;
  final VoidCallback onEdit;
  final Widget categoryRow;
  final Widget tagRow;
  final Widget? suggestionRow;
  final bool isEditing;
  final TextEditingController? titleController;
  final ValueChanged<String>? onTitleChanged;
  final ValueChanged<String>? onBodyChanged;
  final String? rawBody;

  static final _urlRegExp = RegExp(r'^https?://[^\s]+$', caseSensitive: false);

  @override
  State<IdeaTemplateView> createState() => _IdeaTemplateViewState();
}

class _IdeaTemplateViewState extends State<IdeaTemplateView> {
  late final TextEditingController _ideaController;
  late final TextEditingController _sourceController;
  late final TextEditingController _nextActionController;

  @override
  void initState() {
    super.initState();
    _ideaController = TextEditingController(text: widget.data.idea ?? '');
    _sourceController = TextEditingController(text: widget.data.source ?? '');
    _nextActionController =
        TextEditingController(text: widget.data.nextAction ?? '');
  }

  @override
  void didUpdateWidget(IdeaTemplateView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isEditing) {
      if (widget.data.idea != null &&
          widget.data.idea != _ideaController.text) {
        _ideaController.text = widget.data.idea!;
      }
      if (widget.data.source != null &&
          widget.data.source != _sourceController.text) {
        _sourceController.text = widget.data.source!;
      }
      if (widget.data.nextAction != null &&
          widget.data.nextAction != _nextActionController.text) {
        _nextActionController.text = widget.data.nextAction!;
      }
    }
  }

  @override
  void dispose() {
    _ideaController.dispose();
    _sourceController.dispose();
    _nextActionController.dispose();
    super.dispose();
  }

  void _syncBody() {
    final raw = widget.rawBody ?? '';
    final isEnglish = raw.contains('Idea') ||
        raw.contains('idea') ||
        raw.contains('Source:') ||
        raw.contains('Next action:');
    String body;
    if (isEnglish) {
      body = 'Idea: ${_ideaController.text}\n'
          'Source: ${_sourceController.text}\n'
          'Next action: ${_nextActionController.text}';
    } else {
      body = '灵感：${_ideaController.text}\n'
          '来源：${_sourceController.text}\n'
          '下一步行动：${_nextActionController.text}';
    }
    // Round 9: preserve user-added custom lines verbatim so editing through
    // the template UI never drops them.
    final extra = widget.data.extraLines;
    if (extra.isNotEmpty) {
      body = '$body\n${extra.join('\n')}';
    }
    widget.onBodyChanged?.call(body);
  }

  void _copyText(
    BuildContext context,
    String? text,
    String successMessage,
  ) {
    final value = text ?? '';
    if (value.isEmpty) return;
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(successMessage),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final idea = widget.data.idea;
    final source = widget.data.source;
    final nextAction = widget.data.nextAction;

    final title = widget.record?.title.isNotEmpty == true
        ? widget.record!.title
        : l10n.untitledRecord;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Header card (Lightbulb icon + title + pencil edit button)
        TemplateHeaderCard(
          title: title,
          icon: Icons.lightbulb_outline,
          onEdit: widget.onEdit,
          titleController: widget.titleController,
          onTitleChanged: widget.onTitleChanged,
        ),
        const SizedBox(height: 16),

        // 2. Hero Idea card (Prominent content)
        _buildIdeaHeroCard(context, idea, theme, colorScheme, l10n),
        const SizedBox(height: 16),

        // 3. Source row card
        _buildSourceCard(context, source, theme, colorScheme, l10n),
        const SizedBox(height: 16),

        // 4. Next action card (Rocket icon + action or notFilled)
        _buildNextActionCard(context, nextAction, theme, colorScheme, l10n),
        const SizedBox(height: 16),

        // 5. Category & Tag rows container
        Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.6),
            ),
          ),
          child: Column(
            children: [
              widget.categoryRow,
              if (widget.suggestionRow != null) widget.suggestionRow!,
              Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
              widget.tagRow,
            ],
          ),
        ),

        // 6. Updated at relative time or auto-save hint
        if (widget.isEditing)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 10, 4, 14),
            child: Row(
              children: [
                Icon(
                  Icons.cloud_done_outlined,
                  size: 14,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    l10n.autoSaveHint,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color:
                          colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ],
            ),
          )
        else if (widget.record != null)
          UpdatedAtText(dateTime: widget.record!.updatedAt),
      ],
    );
  }

  Widget _buildIdeaHeroCard(
    BuildContext context,
    String? idea,
    ThemeData theme,
    ColorScheme colorScheme,
    AppLocalizations l10n,
  ) {
    final hasContent = idea != null && idea.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left 4px primary accent bar
            Container(
              width: 4,
              color: colorScheme.primary,
            ),
            // Card content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.fieldIdea,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (widget.isEditing)
                      TextField(
                        key: const Key('idea_idea_field'),
                        controller: _ideaController,
                        minLines: 2,
                        maxLines: null,
                        decoration: InputDecoration(
                          hintText: l10n.notFilled,
                          hintStyle: TextStyle(
                            color: colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.5),
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                          height: 1.5,
                        ),
                        onChanged: (_) => _syncBody(),
                      )
                    else if (hasContent)
                      SelectableText(
                        idea,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                          height: 1.5,
                        ),
                      )
                    else
                      Text(
                        l10n.notFilled,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                          height: 1.5,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceCard(
    BuildContext context,
    String? source,
    ThemeData theme,
    ColorScheme colorScheme,
    AppLocalizations l10n,
  ) {
    final hasSource = source != null && source.isNotEmpty;
    final isUrl = hasSource && IdeaTemplateView._urlRegExp.hasMatch(source.trim());

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.fieldSource,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                if (widget.isEditing)
                  TextField(
                    key: const Key('idea_source_field'),
                    controller: _sourceController,
                    decoration: InputDecoration(
                      hintText: l10n.notFilled,
                      hintStyle: TextStyle(
                        color: colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.5),
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurface,
                    ),
                    textInputAction: TextInputAction.next,
                    onChanged: (_) => _syncBody(),
                  )
                else if (!hasSource)
                  Text(
                    l10n.notFilled,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                  )
                else if (isUrl)
                  InkWell(
                    onTap: () => _copyText(context, source, l10n.linkCopied),
                    child: Text(
                      source,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: colorScheme.primary,
                        decoration: TextDecoration.underline,
                        decorationColor: colorScheme.primary,
                      ),
                    ),
                  )
                else
                  SelectableText(
                    source,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurface,
                    ),
                  ),
              ],
            ),
          ),
          if (!widget.isEditing && hasSource) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.copy_rounded, size: 20),
              tooltip: l10n.copy,
              color: colorScheme.onSurfaceVariant,
              onPressed: () => _copyText(
                context,
                source,
                isUrl ? l10n.linkCopied : l10n.copied,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNextActionCard(
    BuildContext context,
    String? nextAction,
    ThemeData theme,
    ColorScheme colorScheme,
    AppLocalizations l10n,
  ) {
    final hasAction = nextAction != null && nextAction.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.rocket_launch_outlined,
              color: colorScheme.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.fieldNextAction,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                if (widget.isEditing)
                  TextField(
                    key: const Key('idea_next_action_field'),
                    controller: _nextActionController,
                    decoration: InputDecoration(
                      hintText: l10n.notFilled,
                      hintStyle: TextStyle(
                        color: colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.5),
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurface,
                    ),
                    onChanged: (_) => _syncBody(),
                  )
                else if (hasAction)
                  SelectableText(
                    nextAction,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurface,
                      height: 1.4,
                    ),
                  )
                else
                  Text(
                    l10n.notFilled,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
