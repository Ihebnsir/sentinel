import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';
import 'ui.dart';

/// Une section de texte : intertitre et paragraphes.
class TextSection {
  const TextSection(this.title, this.paragraphs);

  final String title;
  final List<String> paragraphs;
}

/// Page de lecture simple (politique de confidentialité, audit…) :
/// grand titre, sections séparées par une ligne fine, [footer] en bas.
class TextPage extends StatelessWidget {
  const TextPage({
    super.key,
    required this.title,
    required this.sections,
    this.intro,
    this.footer,
  });

  final String title;
  final String? intro;
  final List<TextSection> sections;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final body = TextStyle(
      fontSize: AppText.corps,
      height: AppText.interligne,
      color: context.colors.secondaire,
    );
    return Scaffold(
      appBar: AppBar(
        backgroundColor: context.colors.chaux,
        foregroundColor: context.colors.encre,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpace.page, AppSpace.sm, AppSpace.page, AppSpace.xxl),
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: AppText.titreSecondaire,
                fontWeight: FontWeight.w600,
                color: context.colors.encre,
              ),
            ),
            if (intro != null) ...[
              const SizedBox(height: AppSpace.lg),
              Text(intro!, style: body),
            ],
            for (final section in sections) ...[
              const SizedBox(height: AppSpace.xl),
              const AppDivider(),
              const SizedBox(height: AppSpace.xl),
              Text(
                section.title,
                style: TextStyle(
                  fontSize: AppText.section,
                  fontWeight: FontWeight.w600,
                  color: context.colors.encre,
                ),
              ),
              const SizedBox(height: AppSpace.md),
              for (final paragraph in section.paragraphs)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.md),
                  child: Text(paragraph, style: body),
                ),
            ],
            if (footer != null) ...[const SizedBox(height: AppSpace.lg), footer!],
          ],
        ),
      ),
    );
  }
}
