import 'dart:io';

void main() {
  final libDir = Directory('lib');
  final allFiles = libDir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart')).toList();
  
  final referencedPaths = <String>{};
  
  for (final file in allFiles) {
    final content = file.readAsStringSync();
    final importRegExp = RegExp(r"import\s+['""]([^'""]+)['""]");
    for (final match in importRegExp.allMatches(content)) {
      final importPath = match.group(1)!;
      if (importPath.startsWith('package:v_effect/')) {
         final relativePath = importPath.replaceFirst('package:v_effect/', 'lib/');
         try { referencedPaths.add(File(relativePath).resolveSymbolicLinksSync()); } catch(e) {}
      } else if (!importPath.startsWith('package:') && !importPath.startsWith('dart:')) {
         try {
           final uri = file.uri.resolve(importPath);
           referencedPaths.add(File.fromUri(uri).resolveSymbolicLinksSync());
         } catch(e) {}
      }
    }
  }
  
  final entryPoints = [
    File('lib/main.dart').resolveSymbolicLinksSync(),
    File('lib/config/routes.dart').resolveSymbolicLinksSync(),
  ];

  for (final file in allFiles) {
    try {
      final resolvedPath = file.resolveSymbolicLinksSync();
      if (!referencedPaths.contains(resolvedPath) && !entryPoints.contains(resolvedPath)) {
        print('Unused file: ${file.path}');
      }
    } catch(e) {}
  }
}
