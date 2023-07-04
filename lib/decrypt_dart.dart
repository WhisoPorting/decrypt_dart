import 'package:args/args.dart';
import 'package:decrypt_dart/decode.dart';
import 'package:decrypt_dart/encode.dart';

ArgResults? getParseCommand(List<String> arguments) {
  final parser = ArgParser()
    ..addCommand('encode')
    ..addCommand('decode');
  ArgResults argResults = parser.parse(arguments);
  return argResults.command;
}

Future<int> invalid(ArgResults command) {
  print('Error: Invalid arguments');
  print('Usage: encode|decode inputFile|folder');
  return Future.value(-1);
}

Future<int> Function(ArgResults command) processingCommand(ArgResults command) {
  return switch (command.name) {
    'encode' => encoding,
    'decode' => decoding,
    _ => invalid,
  };
}

Future<int> engine(List<String> arguments) {
  final command = getParseCommand(arguments);
  if (command == null) {
    print('Error: Invalid arguments');
    print('Usage: encode|decode inputFile|folder');
    return Future.value(-1);
  }
  return processingCommand(command).call(command);
}
