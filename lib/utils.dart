import 'dart:io';

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
