import 'package:args/args.dart';

ArgResults? getParseCommand(List<String> arguments) {
  final parser = ArgParser()
    ..addCommand('encode')
    ..addCommand('decode');
  ArgResults argResults = parser.parse(arguments);
  return argResults.command;
}

int encoding(ArgResults command) {
  return 0;
}

int decoding(ArgResults command) {
  return 0;
}

int invalid(ArgResults command) {
  print('Invalid command');
  return 0;
}

int Function(ArgResults command) processingCommand(ArgResults command) {
  return switch (command.name) {
    'encode' => encoding,
    'decode' => decoding,
    _ => invalid,
  };
}

int engine(List<String> arguments) {
  final command = getParseCommand(arguments);
  if (command == null) {
    print('Error: Invalid arguments');
    print('Usage: encode|decode inputFile|folder');
    return -1;
  }
  return processingCommand(command).call(command);
}
