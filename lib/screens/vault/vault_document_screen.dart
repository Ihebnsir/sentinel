import 'dart:math';
import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import '../../services/vault/vault_crypto.dart';
import '../../services/vault/vault_document_platform.dart';
import '../../services/vault/vault_documents.dart';
import '../../services/vault/vault_item.dart';
import '../../services/vault/vault_platform.dart';
import '../../services/vault/vault_session.dart';
import '../../theme/app_colors.dart';
import '../../widgets/vault_fields.dart';

/// Taille lisible : « 340 Ko », « 2,4 Mo ».
String documentSizeLabel(AppLocalizations l, int bytes) {
  const mb = 1024 * 1024;
  if (bytes < mb) return l.vaultDocSizeKb(l.number(max(1, bytes ~/ 1024)));
  final tenths = (bytes * 10 / mb).round();
  final separator = l.localeName == 'fr' ? ',' : '.';
  return l.vaultDocSizeMb('${tenths ~/ 10}$separator${tenths % 10}');
}

/// « Image » ou « PDF ».
String documentKindLabel(AppLocalizations l, String mime) =>
    mime == 'application/pdf' ? l.vaultDocKindPdf : l.vaultDocKindImage;

/// Un document du coffre : aperçu en mémoire, titre, note, partage.
/// [item] : document existant (déchiffré à l'ouverture) ; sinon [picked],
/// le fichier qui vient d'être pris ou choisi. Se ferme si le coffre se
/// verrouille ; le contenu en clair est effacé en quittant l'écran.
class VaultDocumentScreen extends StatefulWidget {
  const VaultDocumentScreen({
    super.key,
    required this.session,
    this.item,
    this.picked,
  }) : assert((item == null) != (picked == null));

  final VaultSession session;
  final VaultItem? item;
  final PickedDocument? picked;

  @override
  State<VaultDocumentScreen> createState() => _VaultDocumentScreenState();
}

class _VaultDocumentScreenState extends State<VaultDocumentScreen> {
  late final _titre = TextEditingController(
    text: widget.item?.titre ?? _defaultTitle(),
  );
  late final _note = TextEditingController(text: widget.item?.note);

  Uint8List? _bytes; // contenu en clair, en mémoire seulement
  String _mime = '';
  bool _unreadable = false;
  bool _saving = false;
  bool _closing = false;

  // Aperçu des PDF : pages rendues par Android, une à une.
  int? _pageCount;
  bool _pdfFailed = false;
  final _pages = <int, Future<Uint8List?>>{};
  final _pageBytes = <Uint8List>[];

  bool get _isPdf => _mime == 'application/pdf';

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_closeIfLocked);
    VaultPlatform.setSecure(true); // déjà actif sur l'onglet : par sûreté
    final picked = widget.picked;
    if (picked != null) {
      _show(picked.bytes);
    } else {
      _load();
    }
  }

  String? _defaultTitle() {
    final picked = widget.picked;
    if (picked == null) return null;
    final name = picked.name;
    if (name != null && name.trim().isNotEmpty) {
      final dot = name.lastIndexOf('.');
      return dot > 0 ? name.substring(0, dot) : name;
    }
    return null; // photo : titre daté, fixé dans didChangeDependencies
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_titre.text.isEmpty && widget.item == null) {
      _titre.text = context.l10n.vaultDocPhotoTitle(
        context.l10n.date(DateTime.now()),
      );
    }
  }

  Future<void> _load() async {
    try {
      final bytes = await widget.session.readDocument(widget.item!.id);
      if (!mounted || _closing) {
        wipe(bytes);
        return;
      }
      _show(bytes);
    } on VaultCorruptedException {
      if (mounted) setState(() => _unreadable = true);
    } on StateError {
      // Verrouillé pendant le déchiffrement : l'écran se ferme.
    }
  }

  void _show(Uint8List bytes) {
    setState(() {
      _bytes = bytes;
      _mime = detectDocumentMime(bytes) ?? widget.item?.mime ?? '';
    });
    if (_isPdf) _openPdf(bytes);
  }

  Future<void> _openPdf(Uint8List bytes) async {
    final count = await VaultDocumentPlatform.openPdf(bytes);
    if (!mounted) return;
    setState(() {
      _pageCount = count;
      _pdfFailed = count == null || count == 0;
    });
  }

  Future<Uint8List?> _page(int index, int width) =>
      _pages.putIfAbsent(index, () async {
        final png = await VaultDocumentPlatform.renderPdfPage(index, width);
        if (png != null) _pageBytes.add(png);
        return png;
      });

  @override
  void dispose() {
    widget.session.removeListener(_closeIfLocked);
    _titre.dispose();
    _note.dispose();
    if (_isPdf) VaultDocumentPlatform.closePdf();
    // Plus d'image décodée en mémoire, puis octets remis à zéro.
    for (final bytes in [?_bytes, ..._pageBytes]) {
      MemoryImage(bytes).evict();
      wipe(bytes);
    }
    super.dispose();
  }

  void _closeIfLocked() {
    if (_closing || !mounted) return;
    if (widget.session.status == VaultStatus.ouvert) return;
    _closing = true;
    final route = ModalRoute.of(context);
    final navigator = Navigator.of(context);
    navigator.popUntil((r) => r == route);
    navigator.pop();
  }

  Future<void> _save() async {
    final l = context.l10n;
    final titre = _titre.text.trim();
    if (titre.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.vaultNeedTitle)));
      return;
    }
    final bytes = _bytes;
    final existing = widget.item;
    final now = DateTime.now();
    await _run(() {
      if (existing != null) {
        return widget.session.save(
          existing.copyWith(titre: titre, note: _note.text, modifieLe: now),
        );
      }
      return widget.session.addDocument(
        VaultItem(
          id: _newId(),
          type: VaultItemType.document,
          titre: titre,
          note: _note.text,
          mime: _mime,
          taille: bytes!.length,
          creeLe: now,
          modifieLe: now,
        ),
        bytes,
      );
    });
  }

  Future<void> _share() async {
    final bytes = _bytes;
    if (bytes == null) return;
    final l = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.colors.chaux,
        surfaceTintColor: Colors.transparent,
        title: Text(l.vaultDocShareTitle),
        content: Text(l.vaultDocShareWarning),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: context.colors.secondaire,
            ),
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.commonCancel),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: context.colors.rommen),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l.vaultDocShareAnyway),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    // Copie : Android la garde en mémoire jusqu'au verrouillage.
    final shared = await VaultDocumentPlatform.share(
      Uint8List.fromList(bytes),
      _mime,
    );
    if (!shared && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.vaultDocShareFailed)));
    }
  }

  Future<void> _delete() async {
    final l = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.colors.chaux,
        surfaceTintColor: Colors.transparent,
        title: Text(l.vaultDeleteItemTitle(widget.item!.titre)),
        content: Text(l.vaultDeleteItemText),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: context.colors.secondaire,
            ),
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.commonCancel),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: context.colors.rommen),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l.vaultDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run(() => widget.session.delete(widget.item!.id));
  }

  // Enregistre (ou supprime), puis revient à la liste.
  Future<void> _run(Future<void> Function() action) async {
    final l = context.l10n;
    setState(() => _saving = true);
    try {
      await action();
      if (mounted && !_closing) Navigator.of(context).pop();
    } on DocumentTooLargeException {
      _failed(l.vaultDocTooLarge);
    } on UnsupportedDocumentException {
      _failed(l.vaultDocUnsupported);
    } catch (_) {
      _failed(l.vaultSaveFailed);
    }
  }

  void _failed(String message) {
    if (!mounted || _closing) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  static String _newId() {
    final random = Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  void _zoom(Uint8List bytes) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => _ZoomScreen(bytes: bytes)));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final item = widget.item;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: context.colors.chaux,
        foregroundColor: context.colors.encre,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          if (_bytes != null)
            IconButton(
              tooltip: l.vaultDocShare,
              icon: const Icon(Icons.share_outlined),
              onPressed: _saving ? null : _share,
            ),
          if (item != null)
            IconButton(
              tooltip: l.vaultDelete,
              icon: const Icon(Icons.delete_outline),
              onPressed: _saving ? null : _delete,
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(28, 8, 28, 24),
                children: [
                  Text(
                    item == null ? l.vaultNewDocument : l.vaultTypeDocument,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: context.colors.encre,
                    ),
                  ),
                  if (_bytes case final bytes?) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${documentKindLabel(l, _mime)} · '
                      '${documentSizeLabel(l, bytes.length)}',
                      style: TextStyle(
                        fontSize: 13,
                        color: context.colors.secondaire,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  ..._preview(l),
                  const SizedBox(height: 24),
                  VaultTextField(controller: _titre, label: l.vaultFieldTitle),
                  const SizedBox(height: 16),
                  VaultTextField(
                    controller: _note,
                    label: l.vaultFieldNote,
                    minLines: 2,
                    maxLines: 8,
                    keyboardType: TextInputType.multiline,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: context.colors.bleu,
                  ),
                  onPressed: _saving || _bytes == null && item == null
                      ? null
                      : _save,
                  child: Text(_saving ? l.vaultSaving : l.vaultSave),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _preview(AppLocalizations l) {
    final muted = TextStyle(fontSize: 15, color: context.colors.secondaire);
    if (_unreadable) {
      return [
        Text(
          l.vaultDocUnreadable,
          style: TextStyle(fontSize: 15, color: context.colors.rommen),
        ),
      ];
    }
    final bytes = _bytes;
    if (bytes == null) return [Text(l.vaultDocDecrypting, style: muted)];
    if (!_isPdf) {
      return [
        GestureDetector(
          onTap: () => _zoom(bytes),
          child: Image.memory(
            bytes,
            fit: BoxFit.contain,
            gaplessPlayback: true,
            semanticLabel: _titre.text,
          ),
        ),
      ];
    }
    if (_pdfFailed) return [Text(l.vaultDocNoPreview, style: muted)];
    final count = _pageCount;
    if (count == null) return [Text(l.vaultDocDecrypting, style: muted)];
    final width =
        (MediaQuery.sizeOf(context).width *
                MediaQuery.devicePixelRatioOf(context))
            .round();
    return [
      for (var i = 0; i < count; i++) ...[
        if (i > 0) const SizedBox(height: 8),
        FutureBuilder<Uint8List?>(
          future: _page(i, width),
          builder: (context, snapshot) {
            final png = snapshot.data;
            final label = l.vaultDocPage(l.number(i + 1));
            if (png == null) {
              return AspectRatio(
                aspectRatio: 1 / 1.414, // A4, en attendant le rendu
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: context.colors.ligne),
                  ),
                  child: Center(child: Text(label, style: muted)),
                ),
              );
            }
            return GestureDetector(
              onTap: () => _zoom(png),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: context.colors.ligne),
                ),
                child: Image.memory(png, semanticLabel: label),
              ),
            );
          },
        ),
      ],
    ];
  }
}

/// Image (ou page de PDF) en plein écran, zoomable.
class _ZoomScreen extends StatelessWidget {
  const _ZoomScreen({required this.bytes});

  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: InteractiveViewer(
        maxScale: 6,
        child: Center(child: Image.memory(bytes, gaplessPlayback: true)),
      ),
    );
  }
}
