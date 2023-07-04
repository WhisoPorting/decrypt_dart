import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart';
import 'package:encrypt/encrypt.dart';

import 'const.dart';

// This function takes a path as input and returns an array of all files contained in that path, recursively.
List<String> getFilesRecursively(String path) {
  // Check if the path is a file.
  bool isFile = FileSystemEntity.isFileSync(path);

  // If it is, return an array with only that file.
  if (isFile) {
    return [path];
  } else {
    // If it is a directory, create a Directory object for it.
    Directory directory = Directory(path);

    // Get a list of all the files and directories in the directory.
    List<FileSystemEntity> entities = directory.listSync();

    // Create an empty array to store the results.
    List<String> files = [];

    // Iterate through the list of entities and add any files to the results array.
    for (FileSystemEntity entity in entities) {
      if (entity is File) {
        files.add(entity.path);
      } else if (entity is Directory) {
        files.addAll(getFilesRecursively(entity.path));
      }
    }

    // Return the results array.
    return files;
  }
}

String getDirName(String path) => dirname(path);
String getBaseName(String path) => basename(path);
String joinPath(String basePath, String path) => join(basePath, path);

bool createDirIfNotExists(String path) {
  Directory directory = Directory(path);
  if (!directory.existsSync()) {
    try {
      directory.createSync();
    } catch (_) {
      return false;
    }
  }
  return true;
}

// This function takes a file path and a key as input and returns the encrypted data.
Uint8List encryptFile(String filePath) {
  final keyData = Key.fromUtf8(key);

  // Read the file data.
  final file = File(filePath);
  final fileData = file.readAsBytesSync();
  // Create an encryption algorithm.
  var algorithm = Encrypter(AES(keyData, mode: AESMode.cbc));

  // Encrypt the data.
  var encryptedData = algorithm.encryptBytes(
    fileData,
    iv: IV.fromUtf8('0123456789ABCDEF'),
  );

  // Return the encrypted data.
  return encryptedData.bytes;
}

// This function takes a file path and a key as input and returns the encrypted data.
Uint8List decryptFile(String filePath) {
  final keyData = Key.fromUtf8(key);

  // Read the file data.
  File file = File(filePath);
  final fileData = file.readAsBytesSync();
  // Create an encryption algorithm.
  var algorithm = Encrypter(AES(keyData, mode: AESMode.cbc));

  // Encrypt the data.
  final encryptedData = algorithm.decryptBytes(
    Encrypted(fileData),
    iv: IV.fromUtf8('0123456789ABCDEF'),
  );

  // Return the encrypted data.
  return encryptedData as Uint8List;
}

void writeFile(String fileName, Uint8List data) {
  final file = File(fileName);
  file.writeAsBytesSync(data);
}
