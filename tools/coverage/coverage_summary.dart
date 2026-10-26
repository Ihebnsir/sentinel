// Résumé de la couverture de tests de la logique de l'app.
//
// Lit coverage/lcov.info (créé par `flutter test --coverage`), garde
// lib/services, lib/models et lib/utils, et affiche un tableau Markdown
// (fichier par fichier, du moins couvert au plus couvert).
//
// Utilisation :
//   dart run tools/coverage/coverage_summary.dart [lcov.info] [--min=85]
//
// Code de sortie 1 si le total est sous le seuil --min.
// En CI GitHub, le tableau est aussi ajouté au résumé de l'exécution
// (variable GITHUB_STEP_SUMMARY). Aucun service extérieur.
import 'dart:io';

/// Dossiers de logique mesurés (pas les écrans ni les widgets).
const dossiersLogique = ['lib/services/', 'lib/models/', 'lib/utils/'];

void main(List<String> args) {
  var chemin = 'coverage/lcov.info';
  double? minimum;
  for (final arg in args) {
    if (arg.startsWith('--min=')) {
      minimum = double.parse(arg.substring(6));
    } else {
      chemin = arg;
    }
  }

  final fichier = File(chemin);
  if (!fichier.existsSync()) {
    stderr.writeln(
      'Fichier introuvable : $chemin '
      '(lancer d\'abord flutter test --coverage)',
    );
    exit(2);
  }

  final lignes = lireLcov(fichier.readAsLinesSync());
  final logique = {
    for (final e in lignes.entries)
      if (dossiersLogique.any(e.key.startsWith)) e.key: e.value,
  };
  final rapport = tableau(logique);
  stdout.write(rapport);

  final resume = Platform.environment['GITHUB_STEP_SUMMARY'];
  if (resume != null && resume.isNotEmpty) {
    File(resume).writeAsStringSync(rapport, mode: FileMode.append);
  }

  final total = pourcentage(logique.values);
  if (minimum != null && total < minimum) {
    stderr.writeln(
      'Couverture ${total.toStringAsFixed(1)} % '
      'sous le seuil de $minimum %',
    );
    exit(1);
  }
}

/// Lignes (trouvées, couvertes) par fichier, chemins avec des « / ».
Map<String, (int, int)> lireLcov(List<String> lignes) {
  final resultat = <String, (int, int)>{};
  String? courant;
  for (final ligne in lignes) {
    if (ligne.startsWith('SF:')) {
      courant = ligne.substring(3).trim().replaceAll(r'\', '/');
      resultat.putIfAbsent(courant, () => (0, 0));
    } else if (ligne.startsWith('DA:') && courant != null) {
      final parties = ligne.substring(3).split(',');
      final passages = int.parse(parties[1]);
      final (trouvees, couvertes) = resultat[courant]!;
      resultat[courant] = (trouvees + 1, couvertes + (passages > 0 ? 1 : 0));
    }
  }
  return resultat;
}

double pourcentage(Iterable<(int, int)> valeurs) {
  var trouvees = 0;
  var couvertes = 0;
  for (final (t, c) in valeurs) {
    trouvees += t;
    couvertes += c;
  }
  return trouvees == 0 ? 100 : 100 * couvertes / trouvees;
}

String tableau(Map<String, (int, int)> fichiers) {
  final tries = fichiers.entries.toList()
    ..sort((a, b) => pourcentage([a.value]).compareTo(pourcentage([b.value])));
  final sortie = StringBuffer()
    ..writeln('## Couverture de la logique (services, models, utils)')
    ..writeln()
    ..writeln(
      '**Total : ${pourcentage(fichiers.values).toStringAsFixed(1)} %**',
    )
    ..writeln()
    ..writeln('| Fichier | Lignes couvertes | % |')
    ..writeln('|---|---:|---:|');
  for (final e in tries) {
    final (trouvees, couvertes) = e.value;
    sortie.writeln(
      '| ${e.key} | $couvertes / $trouvees | '
      '${pourcentage([e.value]).toStringAsFixed(1)} |',
    );
  }
  sortie.writeln();
  return sortie.toString();
}
