import 'package:args/args.dart';
import 'package:decrypt_dart/utils.dart';

Future<int> decoding(ArgResults command) async {
  if (command.rest.isEmpty || command.rest.first.trim().isEmpty) {
    print('Error: Invalid arguments: missing path or file argument');
    print('Usage: decode inputFile|inputFolder');
    return Future.value(-1);
  }
  final currentPath = command.rest.first.trim();
  final files = getFilesRecursively(currentPath);
  if (files.isEmpty) {
    print('Error: Current path is no valid or path is empty');
    print('Usage: decode inputFile|inputFolder');
    return Future.value(-1);
  }

  for (final fileName in files) {
    final outputDirName = getDirName(fileName);
    final outputBaseName = getBaseName(fileName);
    final outputFolderName = joinPath(outputDirName, 'decrypt');

    if (!createDirIfNotExists(outputFolderName)) {
      print('Error: Could not create working path $outputFolderName');
      return Future.value(0);
    }

    final outputFileName = joinPath(outputFolderName, outputBaseName);
    final encryptData = decryptFile(fileName);
    writeFile(outputFileName, encryptData);
  }

  return Future.value(0);
}
