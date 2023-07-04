import 'package:args/args.dart';
import 'package:decrypt_dart/utils.dart';

int encoding(ArgResults command) {
  if (command.rest.isEmpty || command.rest.first.trim().isEmpty) {
    print('Error: Invalid arguments: missing path or file argument');
    print('Usage: encode inputFile|inputFolder');
    return -1;
  }
  final currentPath = command.rest.first.trim();
  final files = getFilesRecursively(currentPath);
  if (files.isEmpty) {
    print('Error: Current path is no valid or path is empty');
    print('Usage: encode inputFile|inputFolder');
    return -1;
  }
  final theme = Theme.colorfulTheme;
  for (final fileName in files) {
    final progress = Spinner.withTheme(
      theme: theme,
      icon: theme.successPrefix,
      rightPrompt: (done) =>
          done ? 'Finish encoding $fileName' : 'Encoding $fileName',
    ).interact();

    final outputDirName = getDirName(fileName);
    final outputBaseName = getBaseName(fileName);
    final outputFolderName = joinPath(outputDirName, 'encrypt');

    if (!createDirIfNotExists(outputFolderName)) {
      print('Error: Could not create working path $outputFolderName');
      progress.done();
      return -1;
    }

    final outputFileName = joinPath(outputFolderName, outputBaseName);
    final encryptData = encryptFile(fileName);
    writeFile(outputFileName, encryptData);
    progress.done();
  }

  return 0;
}
