import 'package:flutter/material.dart';
import 'package:hoopito/app/design_system/design_system.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/app/l10n/app_localizations_zh.dart';
import 'package:hoopito/core/data/repositories/player_repository.dart';
import 'package:hoopito/core/domain/entities/player.dart';
import 'package:uuid/uuid.dart';

class PlayerEditorPage extends StatefulWidget {
  PlayerEditorPage({
    required this.repository,
    required this.onSaved,
    this.playerId,
    this.onDeleted,
    String Function()? idFactory,
    DateTime Function()? now,
    super.key,
  }) : idFactory = idFactory ?? const Uuid().v4,
       now = now ?? DateTime.now;

  final PlayerRepository repository;
  final String? playerId;
  final VoidCallback onSaved;
  final VoidCallback? onDeleted;
  final String Function() idFactory;
  final DateTime Function() now;

  @override
  State<PlayerEditorPage> createState() => _PlayerEditorPageState();
}

class _PlayerEditorPageState extends State<PlayerEditorPage> {
  final _formKey = GlobalKey<FormState>();
  final _nicknameController = TextEditingController();
  final _noteController = TextEditingController();
  Player? _existing;
  bool _loading = false;
  bool _saving = false;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    if (widget.playerId != null) _load();
  }

  @override
  void didUpdateWidget(covariant PlayerEditorPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playerId == widget.playerId &&
        oldWidget.repository == widget.repository) {
      return;
    }
    _existing = null;
    _nicknameController.clear();
    _noteController.clear();
    _loadError = null;
    _loading = false;
    _saving = false;
    if (widget.playerId != null) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final player = await widget.repository.getById(widget.playerId!);
      if (player == null) throw StateError('Player not found');
      if (!mounted) return;
      _existing = player;
      _nicknameController.text = player.nickname;
      _noteController.text = player.note ?? '';
      setState(() {
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context) ?? AppLocalizationsZh();
    setState(() => _saving = true);
    final note = _noteController.text.trim();
    final player = Player(
      id: _existing?.id ?? widget.idFactory(),
      nickname: _nicknameController.text.trim(),
      createdAt: _existing?.createdAt ?? widget.now(),
      preferredSide: null,
      note: note.isEmpty ? null : note,
    );
    try {
      await widget.repository.save(player);
      if (mounted) widget.onSaved();
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.playerSaveFailed)));
    }
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context) ?? AppLocalizationsZh();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.playerDeleteTitle),
        content: Text(l10n.playerDeleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancelAction),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.deleteAction),
          ),
        ],
      ),
    );
    if (confirmed != true || _existing == null) return;
    try {
      await widget.repository.delete(_existing!.id);
      if (mounted) widget.onDeleted?.call();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.playerDeleteFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context) ?? AppLocalizationsZh();
    final canPop = Navigator.of(context).canPop();
    return EditorialScaffold(
      maxContentWidth: 760,
      masthead: EditorialMasthead(
        title: widget.playerId == null
            ? l10n.playerNewTitle
            : l10n.playerEditTitle,
        leading: canPop
            ? EditorialTapTarget(
                onPressed: () => Navigator.maybePop(context),
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                label: MaterialLocalizations.of(context).backButtonTooltip,
                child: const Icon(Icons.arrow_back),
              )
            : null,
        trailing: _existing != null && widget.onDeleted != null
            ? EditorialTapTarget(
                onPressed: _saving ? null : _delete,
                tooltip: l10n.playerDeleteTooltip,
                label: l10n.playerDeleteTooltip,
                child: Icon(
                  Icons.delete_outline,
                  color: editorialThemeOf(context).ink,
                ),
              )
            : null,
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final l10n = AppLocalizations.of(context) ?? AppLocalizationsZh();
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_loadError != null) {
      return Center(
        child: EditorialErrorState(
          title: l10n.playerOpenError,
          message: l10n.playerOpenErrorBody,
          actionLabel: l10n.retryAction,
          onAction: _load,
        ),
      );
    }
    final editorial = editorialThemeOf(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: HoopitoSpacing.section),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EditorialSectionRule(label: l10n.playerNicknameLabel),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('player-nickname'),
              controller: _nicknameController,
              autofocus: widget.playerId == null,
              textInputAction: TextInputAction.next,
              maxLength: 30,
              decoration: InputDecoration(
                labelText: l10n.playerNicknameLabel,
                prefixIcon: const Icon(Icons.person_outline),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? l10n.playerNicknameRequired
                  : null,
            ),
            const SizedBox(height: 24),
            EditorialSectionRule(label: l10n.playerNoteLabel),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('player-note'),
              controller: _noteController,
              minLines: 3,
              maxLines: 5,
              maxLength: 200,
              decoration: InputDecoration(
                labelText: l10n.playerNoteLabel,
                hintText: l10n.playerNoteHint,
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 20),
            Semantics(
              key: const Key('player-save'),
              button: true,
              enabled: !_saving,
              label: _saving ? l10n.playerSaving : l10n.playerSaveTooltip,
              onTap: _saving ? null : _save,
              child: ExcludeSemantics(
                child: EditorialTapTarget(
                  onPressed: _saving ? null : _save,
                  tooltip: l10n.playerSaveTooltip,
                  child: Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(minHeight: 52),
                    color: _saving ? editorial.rule : editorial.arenaAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_saving)
                          const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          Icon(
                            Icons.save_outlined,
                            color: accessibleForegroundFor(
                              editorial.arenaAccent,
                            ),
                          ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            _saving
                                ? l10n.playerSaving
                                : l10n.playerSaveTooltip,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _saving
                                  ? editorial.mutedInk
                                  : accessibleForegroundFor(
                                      editorial.arenaAccent,
                                    ),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
