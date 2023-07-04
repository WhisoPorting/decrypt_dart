import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:dart_console/dart_console.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as pth;
import 'package:encrypt/encrypt.dart' as enc;
import 'package:tint/tint.dart';
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

String getDirName(String path) => pth.dirname(path);
String getBaseName(String path) => pth.basename(path);
String joinPath(String basePath, String path) => pth.join(basePath, path);

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
  final keyData = enc.Key.fromUtf8(key);

  // Read the file data.
  final file = File(filePath);
  final fileData = file.readAsBytesSync();
  // Create an encryption algorithm.
  var algorithm = enc.Encrypter(enc.AES(keyData, mode: enc.AESMode.cbc));

  // Encrypt the data.
  var encryptedData = algorithm.encryptBytes(
    fileData,
    iv: enc.IV.fromUtf8('0123456789ABCDEF'),
  );

  // Return the encrypted data.
  return encryptedData.bytes;
}

// This function takes a file path and a key as input and returns the encrypted data.
Uint8List decryptFile(String filePath) {
  final keyData = enc.Key.fromUtf8(key);

  // Read the file data.
  File file = File(filePath);
  final fileData = file.readAsBytesSync();
  // Create an encryption algorithm.
  var algorithm = enc.Encrypter(enc.AES(keyData, mode: enc.AESMode.cbc));

  // Encrypt the data.
  final encryptedData = algorithm.decryptBytes(
    enc.Encrypted(fileData),
    iv: enc.IV.fromUtf8('0123456789ABCDEF'),
  );

  // Return the encrypted data.
  return Uint8List.fromList(encryptedData);
}

void writeFile(String fileName, Uint8List data) {
  final file = File(fileName);
  file.writeAsBytesSync(data);
}

// --------------------------------------------------------------

/// A [Component] is an abstraction made with purpose
/// of writing clear/managed state and rendering for
/// various components this library will create.
///
/// Inspired by Flutter's [StatefulWidget], it's is to be used by
/// the [State] class which is used to manage the state of a [Component].
///
/// Generic [T] is the return type of the [Component] which
/// will be returned from the `interact()` function.
abstract class Component<T extends dynamic> {
  /// Creates a [State] for current component,
  /// inspired by Flutter's [StatefulWidget].
  State createState();

  /// Disposes current state, to make the [Context] null and unusable
  /// after the rendering is completely finished.
  ///
  /// Exposed with the purpose to be overriden by [Spinner] and [Progress]
  /// components which dispose the context only when the `done` function
  /// is called.
  void disposeState(State state) => state.dispose();

  /// Pipes the state after running `createState` in case of
  /// needing to handle the state from outside.
  State pipeState(State state) => state;

  // Temporarily stores the number of lines written
  // by the `init()` here
  // to clean them up after `dispose()`
  int _initLinesCount = 0;

  /// Starts the rendering processs.
  ///
  /// Handles not only rendering the `interact` function from the [State]
  /// but also the lifecycle methods such as `init` and `dispose`.
  /// Also does the initial rendering.
  T interact() {
    // Initialize the state
    final state = pipeState(createState());
    state._component = this;
    state.init();
    _initLinesCount = state.context.linesCount;
    state.context.resetLinesCount();

    // Render initially for the first time
    state.render();
    state.context.increaseRenderCount();

    // Start interact and render loop
    final output = state.interact();

    // Clean up once again at last for the first render
    state.context.wipe();

    // Dispose the lines written by `init()`
    state.context.erasePreviousLine(_initLinesCount);
    disposeState(state);

    return output as T;
  }
}

/// Provides the structure and `setState` function.
abstract class State<T extends Component> {
  Context? _context;

  /// The context of the state.
  Context get context {
    if (_context == null) {
      throw Exception(
        "The state's context is already disposed"
        ' '
        'or is not created initially.',
      );
    }
    return _context!;
  }

  /// Changes the context to a new one, not to be used in normal components
  /// except [MultiSpinner] and [MultiProgress] components which requires
  /// custom context overriding.
  void setContext<U extends Context>(U c) => _context = c;

  T? _component;

  /// The component that is using this state.
  T get component {
    if (_component == null) {
      throw Exception(
        'The state is not bind to a component'
        ' '
        'or is already disposed.',
      );
    }
    return _component!;
  }

  /// Runs the [fn] function, erases all lines from the previous
  /// render, and increases the render count after rendering a new state.
  @protected
  @mustCallSuper
  void setState(void Function() fn) {
    fn();
    context.wipe();
    render();
    context.increaseRenderCount();
  }

  /// Initializes the context if it's `null`.
  @mustCallSuper
  void init() {
    _context ??= Context();
  }

  /// Sets the context to `null`.
  @mustCallSuper
  void dispose() {
    _context = null;
  }

  /// Write lines to the console using the context.
  void render() {}

  /// Starts the rendering process. Will be handled by
  /// the [Component]'s `interact` function.
  dynamic interact();
}

final _defaultConsole = Console();

/// [Context] is used by [Component] and [State] to actually render
/// things to the console, and to act as a state store during rendering,
/// which will store things such as the number or renderings done and the
/// amount of lines used by a specific render, so that the [State] can
/// clear old lines and render new stuffs automatically.
class Context {
  /// Resets the Console.
  static void reset() {
    _defaultConsole.showCursor();
    _defaultConsole.resetColorAttributes();
  }

  final _console = _defaultConsole;

  int _renderCount = 0;

  /// Indicates how many times the [Context] has rendered.
  int get renderCount => _renderCount;

  /// Increases the [renderCount] by one.
  void increaseRenderCount() => _renderCount++;

  /// Sets the [renderCount] to `0`.
  void resetRenderCount() => _renderCount = 0;

  int _linesCount = 0;

  /// Indicates how many lines the context is used for rendering.
  int get linesCount => _linesCount;

  /// Increases the [linesCount] by one.
  void increaseLinesCount() => _linesCount++;

  /// Sets the [linesCount] to `0`.
  void resetLinesCount() => _linesCount = 0;

  /// Removes the lines from the last render and reset the lines count.
  void wipe() {
    erasePreviousLine(linesCount);
    resetLinesCount();
  }

  /// Returns terminal width in terms of characters.
  int get windowWidth => _console.windowWidth;

  /// Shows the cursor.
  void showCursor() => _console.showCursor();

  /// Hide the cursor.
  void hideCursor() => _console.hideCursor();

  /// Writes a string to the console.
  void write(String text) => _console.write(text);

  /// Increases the number of lines written for the current render,
  /// and writes a line to the the console.
  void writeln([String? text]) {
    increaseLinesCount();
    _console.writeLine(text);
  }

  /// Erase one line above the current cursor by default.
  ///
  /// If the argument [n] is supplied, it will repeat the process
  /// to [n] times.
  void erasePreviousLine([int n = 1]) {
    for (var i = 0; i < n; i++) {
      _console.cursorUp();
      _console.eraseLine();
    }
  }

  /// Reads a key press, same as dart_console library's
  /// `readKey()` function but this function handles the `Ctrl+C` key
  /// press to immediately exit from the process.
  Key readKey() => _handleKey(_console.readKey());

  /// Reads a line, same as dart_console library's `readLine()` function,
  /// and it's partially taken from the source code of it and modified
  /// for custom use cases, such as accepting initial text as an argument,
  /// and allowing to disable rendering the key press, to use in the [Password]
  /// component.
  String readLine({
    String initialText = '',
    bool noRender = false,
  }) {
    var buffer = initialText;
    var index = buffer.length;

    final screenRow = _console.cursorPosition?.row ?? 0;
    final screenColOffset = _console.cursorPosition?.col ?? 0;
    final bufferMaxLength = _console.windowWidth - screenColOffset - 3;

    if (buffer.isNotEmpty && !noRender) {
      write(buffer);
    }

    while (true) {
      final key = readKey();

      if (key.isControl) {
        switch (key.controlChar) {
          case ControlCharacter.enter:
            writeln();
            return buffer;
          case ControlCharacter.backspace:
          case ControlCharacter.ctrlH:
            if (index > 0) {
              buffer = buffer.substring(0, index - 1) + buffer.substring(index);
              index--;
            }
            break;
          case ControlCharacter.delete:
          case ControlCharacter.ctrlD:
            if (index < buffer.length - 1) {
              buffer = buffer.substring(0, index) + buffer.substring(index + 1);
            }
            break;
          case ControlCharacter.ctrlU:
            buffer = '';
            index = 0;
            break;
          case ControlCharacter.ctrlK:
            buffer = buffer.substring(0, index);
            break;
          case ControlCharacter.arrowLeft:
          case ControlCharacter.ctrlB:
            index = index > 0 ? index - 1 : index;
            break;
          case ControlCharacter.arrowRight:
          case ControlCharacter.ctrlF:
            index = index < buffer.length ? index + 1 : index;
            break;
          case ControlCharacter.wordLeft:
            if (index > 0) {
              final bufferLeftOfCursor = buffer.substring(0, index - 1);
              final lastSpace = bufferLeftOfCursor.lastIndexOf(' ');
              index = lastSpace != -1 ? lastSpace + 1 : 0;
            }
            break;
          case ControlCharacter.home:
          case ControlCharacter.ctrlA:
            index = 0;
            break;
          case ControlCharacter.end:
          case ControlCharacter.ctrlE:
            index = buffer.length;
            break;
          default:
            break;
        }
      } else {
        if (buffer.length < bufferMaxLength) {
          if (index == buffer.length) {
            buffer += key.char;
            index++;
          } else {
            buffer =
                buffer.substring(0, index) + key.char + buffer.substring(index);
            index++;
          }
        }
      }

      if (!noRender) {
        _console.cursorPosition = Coordinate(screenRow, screenColOffset);
        _console.eraseCursorToEnd();
        write(buffer);
        _console.cursorPosition =
            Coordinate(screenRow, screenColOffset + index);
      }
    }
  }

  Key _handleKey(Key key) {
    if (key.isControl && key.controlChar == ControlCharacter.ctrlC) {
      reset();
      exit(1);
    }
    return key;
  }
}

/// Unlike a normal [Context], [BufferContext] writes lines to a specified
/// [StringBuffer] and run a reload function on every line written.
///
/// Useful when waiting for a rendering context when there is multiple
/// of them rendering at the same time. [MultipleSpinner] component used it
/// so when [Spinner]s are being rendered, they get rendered to a [String].
/// It later used the [setState] function to rendered the whole [String]
/// containing multiple [BufferContext]s to the console.
class BufferContext extends Context {
  /// Constructs a [BufferContext] with given properties.
  BufferContext({
    required this.buffer,
    required this.setState,
  });

  /// Buffer stores the lines written to the context.
  final StringBuffer buffer;

  /// Runs everytime something was written to the buffer.
  final void Function() setState;

  @override
  void writeln([String? text]) {
    buffer.clear();
    buffer.write(text);
    setState();
  }
}

// ignore_for_file: public_member_api_docs
// ---
// I can't write docs comments for all of [Theme] properties,
// it's too much.
// But I did use expressive names, so it should be good.

/// [Function] takes a [String] and returns a [String].
///
/// Used for styling texts in the [Theme].
typedef StyleFunction = String Function(String);

/// The theme to be used by components.
class Theme {
  /// Constructs a new [Theme] with all of it's properties.
  const Theme({
    required this.inputPrefix,
    required this.inputSuffix,
    required this.successPrefix,
    required this.successSuffix,
    required this.errorPrefix,
    required this.hiddenPrefix,
    required this.messageStyle,
    required this.errorStyle,
    required this.hintStyle,
    required this.valueStyle,
    required this.defaultStyle,
    required this.activeItemPrefix,
    required this.inactiveItemPrefix,
    required this.activeItemStyle,
    required this.inactiveItemStyle,
    required this.checkedItemPrefix,
    required this.uncheckedItemPrefix,
    required this.pickedItemPrefix,
    required this.unpickedItemPrefix,
    required this.showActiveCursor,
    required this.progressPrefix,
    required this.progressSuffix,
    required this.emptyProgress,
    required this.filledProgress,
    required this.leadingProgress,
    required this.emptyProgressStyle,
    required this.filledProgressStyle,
    required this.leadingProgressStyle,
    required this.spinners,
    required this.spinningInterval,
  });

  final String inputPrefix;
  final String inputSuffix;
  final String successPrefix;
  final String successSuffix;
  final String errorPrefix;
  final String hiddenPrefix;
  final StyleFunction messageStyle;
  final StyleFunction errorStyle;
  final StyleFunction hintStyle;
  final StyleFunction valueStyle;
  final StyleFunction defaultStyle;

  final String activeItemPrefix;
  final String inactiveItemPrefix;
  final StyleFunction activeItemStyle;
  final StyleFunction inactiveItemStyle;

  final String checkedItemPrefix;
  final String uncheckedItemPrefix;

  final String pickedItemPrefix;
  final String unpickedItemPrefix;

  final bool showActiveCursor;

  final String progressPrefix;
  final String progressSuffix;
  final String emptyProgress;
  final String filledProgress;
  final String leadingProgress;
  final StyleFunction emptyProgressStyle;
  final StyleFunction filledProgressStyle;
  final StyleFunction leadingProgressStyle;

  final List<String> spinners;
  final int spinningInterval;

  /// Copy current theme with new properties and create a
  /// new [Theme] from it.
  Theme copyWith({
    String? inputPrefix,
    String? inputSuffix,
    String? successPrefix,
    String? successSuffix,
    String? errorPrefix,
    String? hiddenPrefix,
    StyleFunction? messageStyle,
    StyleFunction? errorStyle,
    StyleFunction? hintStyle,
    StyleFunction? valueStyle,
    StyleFunction? defaultStyle,
    String? activeItemPrefix,
    String? inactiveItemPrefix,
    StyleFunction? activeItemStyle,
    StyleFunction? inactiveItemStyle,
    String? checkedItemPrefix,
    String? uncheckedItemPrefix,
    String? pickedItemPrefix,
    String? unpickedItemPrefix,
    bool? showActiveCursor,
    String? progressPrefix,
    String? progressSuffix,
    String? emptyProgress,
    String? filledProgress,
    String? leadingProgress,
    StyleFunction? emptyProgressStyle,
    StyleFunction? filledProgressStyle,
    StyleFunction? leadingProgressStyle,
    List<String>? spinners,
    int? spinningInterval,
  }) {
    return Theme(
      inputPrefix: inputPrefix ?? this.inputPrefix,
      inputSuffix: inputSuffix ?? this.inputSuffix,
      successPrefix: successPrefix ?? this.successPrefix,
      successSuffix: successSuffix ?? this.successSuffix,
      errorPrefix: errorPrefix ?? this.errorPrefix,
      hiddenPrefix: hiddenPrefix ?? this.hiddenPrefix,
      messageStyle: messageStyle ?? this.messageStyle,
      errorStyle: errorStyle ?? this.errorStyle,
      hintStyle: hintStyle ?? this.hintStyle,
      valueStyle: valueStyle ?? this.valueStyle,
      defaultStyle: defaultStyle ?? this.defaultStyle,
      activeItemPrefix: activeItemPrefix ?? this.activeItemPrefix,
      inactiveItemPrefix: inactiveItemPrefix ?? this.inactiveItemPrefix,
      activeItemStyle: activeItemStyle ?? this.activeItemStyle,
      inactiveItemStyle: inactiveItemStyle ?? this.inactiveItemStyle,
      checkedItemPrefix: checkedItemPrefix ?? this.checkedItemPrefix,
      uncheckedItemPrefix: uncheckedItemPrefix ?? this.uncheckedItemPrefix,
      pickedItemPrefix: pickedItemPrefix ?? this.pickedItemPrefix,
      unpickedItemPrefix: unpickedItemPrefix ?? this.unpickedItemPrefix,
      showActiveCursor: showActiveCursor ?? this.showActiveCursor,
      progressPrefix: progressPrefix ?? this.progressPrefix,
      progressSuffix: progressSuffix ?? this.progressSuffix,
      emptyProgress: emptyProgress ?? this.emptyProgress,
      filledProgress: filledProgress ?? this.filledProgress,
      leadingProgress: leadingProgress ?? this.leadingProgress,
      emptyProgressStyle: emptyProgressStyle ?? this.emptyProgressStyle,
      filledProgressStyle: filledProgressStyle ?? this.filledProgressStyle,
      leadingProgressStyle: leadingProgressStyle ?? this.leadingProgressStyle,
      spinners: spinners ?? this.spinners,
      spinningInterval: spinningInterval ?? this.spinningInterval,
    );
  }

  /// An alias to [colorfulTheme].
  static var defaultTheme = colorfulTheme;

  /// A very basic theme without colors.
  static final basicTheme = Theme(
    inputPrefix: '',
    inputSuffix: ':',
    successPrefix: '',
    successSuffix: ':',
    errorPrefix: 'error: ',
    hiddenPrefix: '[hidden]',
    messageStyle: (x) => x,
    errorStyle: (x) => x,
    hintStyle: (x) => '[$x]',
    valueStyle: (x) => x,
    defaultStyle: (x) => x,
    activeItemPrefix: '>',
    inactiveItemPrefix: ' ',
    activeItemStyle: (x) => x,
    inactiveItemStyle: (x) => x,
    checkedItemPrefix: '[x]',
    uncheckedItemPrefix: '[ ]',
    pickedItemPrefix: '[x]',
    unpickedItemPrefix: '[ ]',
    showActiveCursor: true,
    progressPrefix: '[',
    progressSuffix: ']',
    emptyProgress: ' ',
    filledProgress: '#',
    leadingProgress: '#',
    emptyProgressStyle: (x) => x,
    filledProgressStyle: (x) => x,
    leadingProgressStyle: (x) => x,
    spinners: '⠁⠂⠄⡀⢀⠠⠐⠈'.split(''),
    spinningInterval: 80,
  );

  /// A very colorful theme.
  static final colorfulTheme = Theme(
    inputPrefix: '?'.padRight(2).yellow(),
    inputSuffix: '›'.padLeft(2).grey(),
    successPrefix: '✔'.padRight(2).green(),
    successSuffix: '·'.padLeft(2).grey(),
    errorPrefix: '✘'.padRight(2).red(),
    hiddenPrefix: '****',
    messageStyle: (x) => x.bold(),
    errorStyle: (x) => x.red(),
    hintStyle: (x) => '($x)'.grey(),
    valueStyle: (x) => x.green(),
    defaultStyle: (x) => x.cyan(),
    activeItemPrefix: '❯'.green(),
    inactiveItemPrefix: ' ',
    activeItemStyle: (x) => x.cyan(),
    inactiveItemStyle: (x) => x,
    checkedItemPrefix: '✔'.green(),
    uncheckedItemPrefix: ' ',
    pickedItemPrefix: '❯'.green(),
    unpickedItemPrefix: ' ',
    showActiveCursor: false,
    progressPrefix: '',
    progressSuffix: '',
    emptyProgress: '░',
    filledProgress: '█',
    leadingProgress: '█',
    emptyProgressStyle: (x) => x,
    filledProgressStyle: (x) => x,
    leadingProgressStyle: (x) => x,
    spinners: '⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'.split(''),
    spinningInterval: 80,
  );
}

/// Generates a formatted input message to prompt.
String promptInput({
  required Theme theme,
  required String message,
  String? hint,
}) {
  final buffer = StringBuffer();

  buffer.write(theme.inputPrefix);
  buffer.write(theme.messageStyle(message));
  if (hint != null) {
    buffer.write(' ');
    buffer.write(theme.hintStyle(hint));
  }
  buffer.write(theme.inputSuffix);
  buffer.write(' ');

  return buffer.toString();
}

/// Generates a success prompt, a message to indicates
/// the interaction is successfully finished.
String promptSuccess({
  required Theme theme,
  required String message,
  required String value,
}) {
  final buffer = StringBuffer();

  buffer.write(theme.successPrefix);
  buffer.write(theme.messageStyle(message));
  buffer.write(theme.successSuffix);
  buffer.write(theme.valueStyle(' $value '));

  return buffer.toString();
}

/// Generates a message to use as an error prompt.
String promptError({
  required Theme theme,
  required String message,
}) {
  final buffer = StringBuffer();

  buffer.write(theme.errorPrefix);
  buffer.write(theme.errorStyle(message));

  return buffer.toString();
}

/// Catch sigint and reset to terminal defaults before exit.
StreamSubscription<ProcessSignal> handleSigint() {
  int sigints = 0;
  return ProcessSignal.sigint.watch().listen((event) async {
    if (++sigints >= 1) {
      Context.reset();
      exit(1);
    }
  });
}

/// A confirm component.
class Confirm extends Component<bool> {
  /// Constructs a [Confirm] component with the default theme.
  Confirm({
    required this.prompt,
    this.defaultValue,
    this.waitForNewLine = false,
  }) : theme = Theme.defaultTheme;

  /// Constructs a [Confirm] component with the supplied theme.
  Confirm.withTheme({
    required this.theme,
    required this.prompt,
    this.defaultValue,
    this.waitForNewLine = false,
  });

  /// The theme of the component.
  final Theme theme;

  /// The prompt to be shown together with the user's input.
  final String prompt;

  /// The value to be used as an initial value.
  final bool? defaultValue;

  /// Determines whether to wait for the Enter key after
  /// the user has responded.
  final bool waitForNewLine;

  @override
  _ConfirmState createState() => _ConfirmState();
}

class _ConfirmState extends State<Confirm> {
  bool? answer;

  @override
  void init() {
    super.init();
    if (component.defaultValue != null) {
      answer = component.defaultValue;
    }
    context.hideCursor();
  }

  @override
  void dispose() {
    context.writeln(promptSuccess(
      theme: component.theme,
      message: component.prompt,
      value: answer! ? 'yes' : 'no',
    ));
    context.showCursor();

    super.dispose();
  }

  @override
  void render() {
    final line = StringBuffer();
    line.write(promptInput(
      theme: component.theme,
      message: component.prompt,
      hint: 'y/n',
    ));
    if (answer != null) {
      line.write(component.theme.defaultStyle(answer! ? 'yes' : 'no'));
    }
    context.writeln(line.toString());
  }

  @override
  bool interact() {
    while (true) {
      final key = context.readKey();

      if (key.isControl) {
        if (key.controlChar == ControlCharacter.enter &&
            answer != null &&
            (component.waitForNewLine || component.defaultValue != null)) {
          return answer!;
        }
      } else {
        switch (key.char) {
          case 'y':
          case 'Y':
            setState(() {
              answer = true;
            });
            if (!component.waitForNewLine) {
              return answer!;
            }
            break;
          case 'n':
          case 'N':
            setState(() {
              answer = false;
            });
            if (!component.waitForNewLine) {
              return answer!;
            }
            break;
          default:
            break;
        }
      }
    }
  }
}

String _prompt(bool x) => '';

/// A spinner or a loading indicator component.
class Spinner extends Component<SpinnerState> {
  /// Construts a [Spinner] component with the default theme.
  Spinner({
    required this.icon,
    this.leftPrompt = _prompt,
    this.rightPrompt = _prompt,
  }) : theme = Theme.defaultTheme;

  /// Constructs a [Spinner] component with the supplied theme.
  Spinner.withTheme({
    required this.icon,
    required this.theme,
    this.leftPrompt = _prompt,
    this.rightPrompt = _prompt,
  });

  Context? _context;

  /// The theme of the component.
  final Theme theme;

  /// The icon to be shown in place of the loading
  /// indicator after it's done.
  final String icon;

  /// The prompt function to be shown on the left side
  /// of the spinning indicator or icon.
  final String Function(bool) leftPrompt;

  /// The prompt function to be shown on the right side
  /// of the spinning indicator or icon.
  final String Function(bool) rightPrompt;

  @override
  _SpinnerState createState() => _SpinnerState();

  @override
  void disposeState(State state) {}

  @override
  State pipeState(State state) {
    if (_context != null) {
      state.setContext(_context!);
    }
    return state;
  }

  /// Sets the context to a new one,
  /// to be used internally by [MultiSpinner].
  void setContext(Context c) => _context = c;
}

/// Handles a [Spinner]'s state.
class SpinnerState {
  /// Constructs a state to manage a [Spinner].
  SpinnerState({required this.done});

  /// Function to be called to indicate that the
  /// spinner is loaded.
  void Function() Function() done;
}

class _SpinnerState extends State<Spinner> {
  late bool done;
  late int index;
  late StreamSubscription<ProcessSignal> sigint;

  @override
  void init() {
    super.init();
    done = false;
    index = 0;
    sigint = handleSigint();
    context.hideCursor();
  }

  @override
  void dispose() {
    context.showCursor();
    super.dispose();
  }

  @override
  void render() {
    final line = StringBuffer();

    line.write(component.leftPrompt(done));

    if (done) {
      line.write(component.icon);
    } else {
      line.write(component.theme.spinners[index]);
    }
    line.write(' ');
    line.write(component.rightPrompt(done));

    context.writeln(line.toString());
  }

  @override
  SpinnerState interact() {
    final timer = Timer.periodic(
      Duration(
        milliseconds: component.theme.spinningInterval,
      ),
      (timer) {
        setState(() {
          index = (index + 1) % component.theme.spinners.length;
        });
      },
    );

    final state = SpinnerState(
      done: () {
        if (done) return () {};
        setState(() {
          done = true;
          sigint.cancel();
        });
        timer.cancel();
        if (component._context != null) {
          return dispose;
        } else {
          dispose();
          return () {};
        }
      },
    );

    return state;
  }
}
