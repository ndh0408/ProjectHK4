import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/theme.dart';
import '../../../../l10n/app_localizations.dart';

class DescriptionEditorScreen extends StatefulWidget {
  const DescriptionEditorScreen({
    super.key,
    this.initialValue,
  });

  final String? initialValue;

  @override
  State<DescriptionEditorScreen> createState() => _DescriptionEditorScreenState();
}

class _DescriptionEditorScreenState extends State<DescriptionEditorScreen>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _controller;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue ?? '');
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _insertMarkdown(String prefix, String suffix, {String? placeholder}) {
    final text = _controller.text;
    final selection = _controller.selection;

    if (selection.isValid && selection.start != selection.end) {
      final selectedText = text.substring(selection.start, selection.end);
      final newText = text.replaceRange(
        selection.start,
        selection.end,
        '$prefix$selectedText$suffix',
      );
      _controller.text = newText;
      _controller.selection = TextSelection.collapsed(
        offset: selection.start + prefix.length + selectedText.length + suffix.length,
      );
    } else {
      final insertText = '$prefix${placeholder ?? ''}$suffix';
      final cursorPos = selection.baseOffset;
      final newText = text.substring(0, cursorPos) + insertText + text.substring(cursorPos);
      _controller.text = newText;
      _controller.selection = TextSelection.collapsed(
        offset: cursorPos + prefix.length + (placeholder?.length ?? 0),
      );
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          AppLocalizations.of(context)!.eventDescription,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () => context.pop(_controller.text),
            child: Text(
              AppLocalizations.of(context)!.done,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey[600],
          indicatorColor: AppColors.primary,
          tabs: [
            Tab(text: AppLocalizations.of(context)!.write),
            Tab(text: AppLocalizations.of(context)!.preview),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              border: Border(
                bottom: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _ToolbarButton(
                    icon: Icons.format_bold,
                    tooltip: AppLocalizations.of(context)!.bold,
                    onPressed: () => _insertMarkdown('**', '**', placeholder: 'bold text'),
                  ),
                  _ToolbarButton(
                    icon: Icons.format_italic,
                    tooltip: AppLocalizations.of(context)!.italic,
                    onPressed: () => _insertMarkdown('*', '*', placeholder: 'italic text'),
                  ),
                  _ToolbarButton(
                    icon: Icons.strikethrough_s,
                    tooltip: AppLocalizations.of(context)!.strikethrough,
                    onPressed: () => _insertMarkdown('~~', '~~', placeholder: 'strikethrough'),
                  ),
                  const _ToolbarDivider(),
                  _ToolbarButton(
                    icon: Icons.title,
                    tooltip: AppLocalizations.of(context)!.heading,
                    onPressed: () => _insertMarkdown('## ', '', placeholder: 'Heading'),
                  ),
                  _ToolbarButton(
                    icon: Icons.format_list_bulleted,
                    tooltip: AppLocalizations.of(context)!.bulletList,
                    onPressed: () => _insertMarkdown('\n- ', '', placeholder: 'List item'),
                  ),
                  _ToolbarButton(
                    icon: Icons.format_list_numbered,
                    tooltip: AppLocalizations.of(context)!.numberedList,
                    onPressed: () => _insertMarkdown('\n1. ', '', placeholder: 'List item'),
                  ),
                  const _ToolbarDivider(),
                  _ToolbarButton(
                    icon: Icons.link,
                    tooltip: AppLocalizations.of(context)!.link,
                    onPressed: () => _showLinkDialog(),
                  ),
                  _ToolbarButton(
                    icon: Icons.code,
                    tooltip: AppLocalizations.of(context)!.code,
                    onPressed: () => _insertMarkdown('`', '`', placeholder: 'code'),
                  ),
                  _ToolbarButton(
                    icon: Icons.format_quote,
                    tooltip: AppLocalizations.of(context)!.quote,
                    onPressed: () => _insertMarkdown('\n> ', '', placeholder: 'quote'),
                  ),
                  const _ToolbarDivider(),
                  _ToolbarButton(
                    icon: Icons.horizontal_rule,
                    tooltip: AppLocalizations.of(context)!.horizontalRule,
                    onPressed: () => _insertMarkdown('\n---\n', ''),
                  ),
                ],
              ),
            ),
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _controller,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    decoration: InputDecoration(
                      hintText: AppLocalizations.of(context)!.describeYourEvent,
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.5,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),

                _controller.text.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.preview_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              AppLocalizations.of(context)!.nothingToPreview,
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              AppLocalizations.of(context)!.startWritingToPreview,
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      )
                    : Markdown(
                        data: _controller.text,
                        padding: const EdgeInsets.all(16),
                        styleSheet: MarkdownStyleSheet(
                          p: const TextStyle(fontSize: 16, height: 1.5),
                          h1: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                          h2: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          h3: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          listBullet: const TextStyle(fontSize: 16),
                          code: TextStyle(
                            backgroundColor: Colors.grey[200],
                            fontFamily: 'monospace',
                          ),
                          blockquote: TextStyle(
                            color: Colors.grey[700],
                            fontStyle: FontStyle.italic,
                          ),
                          blockquoteDecoration: BoxDecoration(
                            border: Border(
                              left: BorderSide(
                                color: Colors.grey[400]!,
                                width: 4,
                              ),
                            ),
                          ),
                        ),
                      ),
              ],
            ),
          ),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              border: Border(
                top: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppLocalizations.of(context)!.supportsMarkdown,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
                Text(
                  '${_controller.text.length} ${AppLocalizations.of(context)!.characters}',
                  style: TextStyle(
                    color: _controller.text.length < 20 ? Colors.orange : Colors.grey[600],
                    fontSize: 12,
                    fontWeight: _controller.text.length < 20 ? FontWeight.w500 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showLinkDialog() {
    final linkTextController = TextEditingController();
    final linkUrlController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        final l10n = AppLocalizations.of(dialogContext)!;
        return AlertDialog(
          title: Text(l10n.insertLink),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: linkTextController,
                decoration: InputDecoration(
                  labelText: l10n.linkText,
                  hintText: 'Click here',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: linkUrlController,
                decoration: InputDecoration(
                  labelText: l10n.url,
                  hintText: 'https://example.com',
                ),
                keyboardType: TextInputType.url,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                final text = linkTextController.text.isNotEmpty
                    ? linkTextController.text
                    : 'link';
                final url = linkUrlController.text.isNotEmpty
                    ? linkUrlController.text
                    : 'url';
                _insertMarkdown('[$text](', ')', placeholder: url);
              },
              child: Text(l10n.insert),
            ),
          ],
        );
      },
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 20),
      tooltip: tooltip,
      onPressed: onPressed,
      color: Colors.grey[700],
      splashRadius: 20,
    );
  }
}

class _ToolbarDivider extends StatelessWidget {
  const _ToolbarDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: Colors.grey[300],
    );
  }
}
