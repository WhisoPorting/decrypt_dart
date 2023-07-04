import 'package:args/args.dart';
import 'package:decrypt_dart/utils.dart';

int decoding(ArgResults command) {
  if (command.rest.isEmpty || command.rest.first.trim().isEmpty) {
    print('Error: Invalid arguments: missing path or file argument');
    print('Usage: decode inputFile|inputFolder');
    return -1;
  }
  final currentPath = command.rest.first.trim();
  final files = getFilesRecursively(currentPath);
  if (files.isEmpty) {
    print('Error: Current path is no valid or path is empty');
    print('Usage: decode inputFile|inputFolder');
    return -1;
  }

  for (final fileName in files) {
    final outputDirName = getDirName(fileName);
    final outputBaseName = getBaseName(fileName);
    final outputFolderName = joinPath(outputDirName, 'decrypt');

    if (!createDirIfNotExists(outputFolderName)) {
      print('Error: Could not create working path $outputFolderName');
      return -1;
    }

    final outputFileName = joinPath(outputFolderName, outputBaseName);
    final encryptData = decryptFile(fileName);
    writeFile(outputFileName, encryptData);
  }

  return 0;
}
