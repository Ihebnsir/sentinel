import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';

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
      fontSize: 15,
      height: 1.45,
      color: AppColors.encre.withValues(alpha: 0.8),
    );
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.chaux,
        foregroundColor: AppColors.encre,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(28, 8, 28, 32),
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: AppColors.encre,
              ),
            ),
            if (intro != null) ...[
              const SizedBox(height: 16),
              Text(intro!, style: body),
            ],
            for (final section in sections) ...[
              const SizedBox(height: 20),
              const Divider(height: 1, thickness: 1, color: AppColors.ligne),
              const SizedBox(height: 20),
              Text(
                section.title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: AppColors.encre,
                ),
              ),
              const SizedBox(height: 10),
              for (final paragraph in section.paragraphs)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(paragraph, style: body),
                ),
            ],
            if (footer != null) ...[const SizedBox(height: 16), footer!],
          ],
        ),
      ),
    );
  }
}
