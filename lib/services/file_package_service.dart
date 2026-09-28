import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'file_package_service.g.dart';

class SelectedSourceFile {
  final String name;
  final String path;
  final int size;

  const SelectedSourceFile({
    required this.name,
    required this.path,
    required this.size,
  });
}

class FilePackageService {
  Future<List<SelectedSourceFile>> pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: false,
    );

    if (result == null) return [];

    return result.files
        .where((f) => f.path != null)
        .map(
          (f) => SelectedSourceFile(name: f.name, path: f.path!, size: f.size),
        )
        .toList();
  }

  Future<SelectedSourceFile?> pickZip() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: ['zip'],
      withData: false,
    );
    if (result == null || result.files.single.path == null) return null;
    final f = result.files.single;
    return SelectedSourceFile(name: f.name, path: f.path!, size: f.size);
  }

  Future<String> buildEvaluationSource(List<SelectedSourceFile> files) async {
    const maxEvaluationCharacters = 180000;
    var usedCharacters = 0;
    final buffer = StringBuffer();

    bool append(String name, String content) {
      if (usedCharacters >= maxEvaluationCharacters) return false;
      final remaining = maxEvaluationCharacters - usedCharacters;
      final clipped = content.length > remaining
          ? content.substring(0, remaining)
          : content;
      buffer.writeln('\n===== $name =====\n$clipped');
      usedCharacters += clipped.length;
      return usedCharacters < maxEvaluationCharacters;
    }

    for (final source in files) {
      if (usedCharacters >= maxEvaluationCharacters) break;

      final file = File(source.path);
      if (!await file.exists()) continue;

      final lower = source.name.toLowerCase();
      if (lower.endsWith('.zip')) {
        try {
          final bytes = await file.readAsBytes();
          final archive = ZipDecoder().decodeBytes(bytes);
          for (final entry in archive) {
            if (!entry.isFile || usedCharacters >= maxEvaluationCharacters) break;
            final name = entry.name;
            final normalized = name.replaceAll('\\', '/').toLowerCase();
            if (_isIgnoredPath(normalized)) continue;
            final textLike = RegExp(
              r'\.(dart|rs|py|js|ts|tsx|jsx|java|kt|cpp|c|h|hpp|json|yaml|yml|toml|xml|md|txt|html|css|sql)$',
              caseSensitive: false,
            ).hasMatch(name);
            if (!textLike) continue;
            final content = entry.readBytes();
            if (content == null) continue;
            final decoded = String.fromCharCodes(content);
            if (!append(name, decoded)) break;
          }
        } catch (_) {
          append(source.name, '[ZIP could not be inspected]');
        }
      } else {
        if (_isIgnoredPath(lower)) continue;
        final textLike = RegExp(
          r'\.(dart|rs|py|js|ts|tsx|jsx|java|kt|cpp|c|h|hpp|json|yaml|yml|toml|xml|md|txt|html|css|sql)$',
          caseSensitive: false,
        ).hasMatch(lower);
        if (!textLike) continue;
        try {
          final content = await file.readAsString();
          if (!append(source.name, content)) break;
        } catch (_) {
          append(source.name, '[File could not be read as text]');
        }
      }
    }

    if (usedCharacters >= maxEvaluationCharacters) {
      buffer.writeln(
        '\n===== DevSprint evaluation note =====\n'
        '[Evaluation source was capped at 180,000 characters. The submitted ZIP remains complete.]',
      );
    }

    return buffer.toString();
  }

  bool _isIgnoredPath(String path) {
    final normalized = path.replaceAll('\\', '/');
    const ignoredDirectories = [
      '/.git/',
      '/node_modules/',
      '/build/',
      '/dist/',
      '/target/',
      '/.dart_tool/',
      '/android/.gradle/',
      '/ios/pods/',
    ];
    final wrapped = normalized.startsWith('/') ? normalized : '/$normalized';
    return ignoredDirectories.any(wrapped.contains) ||
        normalized.startsWith('.git/') ||
        normalized.startsWith('node_modules/') ||
        normalized.startsWith('build/') ||
        normalized.startsWith('dist/') ||
        normalized.startsWith('target/') ||
        normalized.startsWith('.dart_tool/');
  }

  Future<File> createZip(List<SelectedSourceFile> files) async {
    if (files.isEmpty) {
      throw StateError('Add at least one file before creating a package.');
    }

    final root = await getApplicationSupportDirectory();
    final submissions = Directory('${root.path}/submissions');
    await submissions.create(recursive: true);
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final output = File('${submissions.path}/devsprint_submission_$stamp.zip');

    final encoder = ZipFileEncoder();
    encoder.create(output.path);
    for (final source in files) {
      final file = File(source.path);
      if (await file.exists()) {
        encoder.addFile(file, source.name);
      }
    }
    encoder.close();
    return output;
  }
}

@riverpod
FilePackageService filePackageService(Ref ref) => FilePackageService();
