# Effective Dart: Complete Style, Documentation, Usage & Design Guide

This skill compiles all four Effective Dart guides into a single comprehensive reference for writing consistent, maintainable Dart code.

---

## 1. Style

Formatting and naming rules for consistent, readable code. Consistent naming, ordering, and formatting helps code that is the same look the same.

### 1.1 Identifiers

Identifiers come in three flavors in Dart:
- **UpperCamelCase** – capitalize the first letter of each word, including the first
- **lowerCamelCase** – capitalize the first letter of each word, except the first which is always lowercase
- **lowercase_with_underscores** – use only lowercase letters, even for acronyms, and separate words with `_`

#### DO name types using UpperCamelCase

Linter rule: [`camel_case_types`](https://dart.dev/tools/linter-rules/camel_case_types)

Classes, enum types, typedefs, and type parameters should capitalize the first letter of each word (including the first word), and use no separators.

```dart
// good
class SliderMenu { ... }
class HttpRequest { ... }
typedef Predicate = bool Function(T value);
```

This even includes classes intended to be used in metadata annotations.

#### DO name extensions using UpperCamelCase

Like types, extensions should capitalize the first letter of each word.

```dart
// good
extension MyFancyList on List { ... }
extension SmartIterable on Iterable { ... }
```

#### DO name packages, directories, and source files using lowercase_with_underscores

Some file systems are not case-sensitive, so many projects require filenames to be all lowercase.

```
// good
my_package
└── lib
    └── file_system.dart
    └── slider_menu.dart

// bad
mypackage
└── lib
    └── file-system.dart
    └── SliderMenu.dart
```

#### DO name import prefixes using lowercase_with_underscores

Linter rule: [`library_prefixes`](https://dart.dev/tools/linter-rules/library_prefixes)

```dart
// good
import 'dart:math' as math;
import 'package:angular_components/angular_components.dart' as angular_components;

// bad
import 'dart:math' as Math;
import 'package:angular_components/angular_components.dart' as angularComponents;
```

#### DO name other identifiers using lowerCamelCase

Class members, top-level definitions, variables, parameters, and named parameters should capitalize the first letter of each word except the first word, and use no separators.

```dart
// good
var count = 3;
HttpRequest httpRequest;
void align(bool clearItems) { ... }
```

#### PREFER using lowerCamelCase for constant names

In new code, use lowerCamelCase for constant variables, including enum values.

```dart
// good
const pi = 3.14;
const defaultTimeout = 1000;
final urlScheme = RegExp('^([a-z]+):');
class Dice {
  static final numberGenerator = Random();
}

// bad
const PI = 3.14;
const DefaultTimeout = 1000;
final URL_SCHEME = RegExp('^([a-z]+):');
```

You may use SCREAMING_CAPS for consistency with existing code.

#### DO capitalize acronyms and abbreviations longer than two letters like words

Capitalized acronyms can be hard to read.

```dart
// good - longer than two letters, like a word
Http   // "hypertext transfer protocol"
Nasa   // "national aeronautics and space administration"
Uri    // "uniform resource identifier"

// good - two letters, capitalized in English
ID     // "identifier"
TV     // "television"
UI     // "user interface"

// good - two letters, not capitalized in English
Mr     // "mister"
St     // "street"
Rd     // "road"
```

When any form of abbreviation comes at the beginning of a lowerCamelCase identifier, the abbreviation should be all lowercase.

```dart
var httpConnection = connect();
var tvSet = Television();
var mrRogers = 'hello, neighbor';
```

#### PREFER using wildcards for unused callback parameters

Name unused parameters `_` (wildcard variable).

```dart
// good
futureOfVoid.then((_) {
  print('Operation complete.');
});

// Multiple unused parameters
.onError((_, _) {
  print('Operation failed.');
});
```

This guideline is only for anonymous and local functions.

#### DON'T use a leading underscore for identifiers that aren't private

Dart uses a leading underscore to mark members and top-level declarations as private.

#### DON'T use prefix letters (Hungarian notation)

Dart can tell you the type, scope, mutability, and other properties of your declarations, so there's no reason to encode those properties in identifier names.

```dart
// good
defaultTimeout

// bad
kDefaultTimeout
```

#### DON'T explicitly name libraries

Appending a name to the `library` directive is a legacy feature and discouraged.

```dart
// bad
library my_library;

// good
/// A really great test library.
@TestOn('browser')
library;
```

### 1.2 Ordering

To keep the preamble of your file tidy, there is a prescribed order that directives should appear in. Each "section" should be separated by a blank line.

A single linter rule handles all ordering guidelines: [`directives_ordering`](https://dart.dev/tools/linter-rules/directives_ordering).

#### DO place dart: imports before other imports

```dart
// good
import 'dart:async';
import 'dart:collection';
import 'package:bar/bar.dart';
import 'package:foo/foo.dart';
```

#### DO place package: imports before relative imports

```dart
// good
import 'package:bar/bar.dart';
import 'package:foo/foo.dart';
import 'util.dart';
```

#### DO specify exports in a separate section after all imports

```dart
// good
import 'src/error.dart';
import 'src/foo_bar.dart';

export 'src/error.dart';

// bad
import 'src/error.dart';
export 'src/error.dart';
import 'src/foo_bar.dart';
```

#### DO sort sections alphabetically

```dart
// good
import 'package:bar/bar.dart';
import 'package:foo/foo.dart';
import 'foo.dart';
import 'foo/foo.dart';

// bad
import 'package:foo/foo.dart';
import 'package:bar/bar.dart';
import 'foo/foo.dart';
import 'foo.dart';
```

### 1.3 Formatting

#### DO format your code using dart format

The official whitespace-handling rules for Dart are whatever `dart format` produces.

#### CONSIDER changing your code to make it more formatter-friendly

If formatted output is still hard to read, reorganize or simplify your code. Think of `dart format` as a partnership.

#### PREFER lines 80 characters or fewer

Readability studies show that long lines of text are harder to read.

Note that `dart format` defaults to 80 characters. It does not split long string literals, so you have to do that manually.

**Exceptions:**
- URIs or file paths in comments or strings may remain whole
- Multi-line strings can contain lines longer than 80 characters

#### DO use curly braces for all flow control statements

This avoids the dangling else problem.

```dart
// good
if (isWeekDay) {
  print('Bike to work!');
} else {
  print('Go dancing or read a book!');
}
```

**Exception:** When you have an `if` statement with no `else` clause and the whole `if` statement fits on one line, you can omit the braces.

```dart
// good
if (arg == null) return defaultValue;

// If body wraps, use braces
if (overflowChars != other.overflowChars) {
  return overflowChars < other.overflowChars;
}
```

---

## 2. Documentation

Clear, helpful comments and documentation.

### 2.1 Comments

#### DO format comments like sentences

Capitalize the first word unless it's a case-sensitive identifier. End with a period (or "!" or "?"). This is true for all comments: doc comments, inline stuff, even TODOs.

```dart
// good
// Not if anything comes before it.
if (_chunks.isNotEmpty) return false;
```

#### DON'T use block comments for documentation

Use `//` for all comments. Block comments (`/* ... */`) should only be used to temporarily comment out code.

```dart
// good
void greet(String name) {
  // Assume we have a valid name.
  print('Hi, $name!');
}

// bad
void greet(String name) {
  /* Assume we have a valid name. */
  print('Hi, $name!');
}
```

### 2.2 Doc Comments

Doc comments use the `///` syntax that `dart doc` parses.

#### DO use /// doc comments to document members and types

Using a doc comment enables `dart doc` to find it and generate documentation.

```dart
// good
/// The number of characters in this chunk when unsplit.
int get length => ...

// bad
// The number of characters in this chunk when unsplit.
int get length => ...
```

Prefer `///` over `/** ... */` because it's more compact.

#### PREFER writing doc comments for public APIs

You don't have to document every single library, but you should document most of them.

#### CONSIDER writing a library-level doc comment

Place a doc comment before the `library` directive.

Consider including:
- A single-sentence summary of what the library is for
- Explanations of terminology used throughout the library
- A couple of complete code samples
- Links to the most important or most commonly used classes and functions
- Links to external references

```dart
/// A really great test library.
@TestOn('browser')
library;
```

#### CONSIDER writing doc comments for private APIs

Doc comments can be helpful for understanding private members.

#### DO start doc comments with a single-sentence summary

Start with a brief, user-centric description ending with a period.

```dart
// good
/// Deletes the file at [path] from the file system.
void delete(String path) { ... }

// bad - too much detail in first sentence
/// Depending on the state of the file system and the user's permissions,
/// certain operations may or may not be possible...
void delete(String path) { ... }
```

#### DO separate the first sentence of a doc comment into its own paragraph

Add a blank line after the first sentence. Tools like `dart doc` use the first paragraph as a short summary.

```dart
// good
/// Deletes the file at [path].
///
/// Throws an [IOError] if the file could not be found. Throws a
/// [PermissionError] if the file is present but could not be deleted.
void delete(String path) { ... }
```

#### AVOID redundancy with the surrounding context

Focus on explaining what the reader doesn't already know.

```dart
// good
class RadioButtonWidget extends Widget {
  /// Sets the tooltip to [lines].
  ///
  /// The lines should be word wrapped using the current font.
  void tooltip(List lines) { ... }
}

// bad
class RadioButtonWidget extends Widget {
  /// Sets the tooltip for this radio button widget to the list of strings in
  /// [lines].
  void tooltip(List lines) { ... }
}
```

#### PREFER starting comments of a function or method with third-person verbs if its main purpose is a side effect

```dart
/// Connects to the server and fetches the query results.
Stream fetchResults(Query query) => ...

/// Starts the stopwatch if not already running.
void start() => ...
```

#### PREFER starting a non-boolean variable or property comment with a noun phrase

```dart
/// The current day of the week, where `0` is Sunday.
int weekday;

/// The number of checked buttons on the page.
int get checkedCount => ...
```

#### PREFER starting a boolean variable or property comment with "Whether" followed by a noun or gerund phrase

```dart
/// Whether the modal is currently displayed to the user.
bool isVisible;

/// Whether the modal should confirm the user's intent on navigation.
bool get shouldConfirm => ...

/// Whether resizing the current browser window will also resize the modal.
bool get canResize => ...
```

#### PREFER a noun phrase or non-imperative verb phrase for a function or method if returning a value is its primary purpose

```dart
/// The [index]th element of this iterable in iteration order.
E elementAt(int index);

/// Whether this iterable contains an element equal to [element].
bool contains(Object? element);
```

#### DON'T write documentation for both the getter and setter of a property

`dart doc` treats the getter and setter like a single field and discards the setter's doc comment.

```dart
// good
/// The pH level of the water in the pool.
///
/// Ranges from 0-14, representing acidic to basic, with 7 being neutral.
int get phLevel => ...
set phLevel(int level) => ...

// bad
/// The depth of the water in the pool, in meters.
int get waterDepth => ...
/// Updates the water depth to a total of [meters] in height.
set waterDepth(int meters) => ...
```

#### PREFER starting library or type comments with noun phrases

```dart
/// A chunk of non-breaking output text terminated by a hard or soft newline.
///
/// ...
class Chunk { ... }
```

#### CONSIDER including code samples in doc comments

Humans are great at generalizing from examples.

```dart
/// The lesser of two numbers.
///
/// ```dart
/// min(5, 3) == 3
/// ```
num min(num a, num b) => ...
```

#### DO use square brackets in doc comments to refer to in-scope identifiers

`dart doc` looks up the name and links to the relevant API docs. Parentheses are optional.

```dart
/// Throws a [StateError] if ...
///
/// Similar to [anotherMethod()], but ...
```

To link to a member of a specific class, use the class name and member name, separated by a dot:

```dart
/// Similar to [Duration.inDays], but handles fractional days.
```

#### DO use prose to explain parameters, return values, and exceptions

The convention in Dart is to integrate this into the description and highlight parameters using square brackets.

```dart
// good
/// Defines a flag with the given [name] and [abbreviation].
///
/// The [name] and [abbreviation] strings must not be empty.
///
/// Returns a new flag.
///
/// Throws a [DuplicateFlagException] if there is already an option named
/// [name] or there is already an option using the [abbreviation].
Flag addFlag(String name, String abbreviation) => ...

// bad - using @param tags
/// Defines a flag with the given name and abbreviation.
///
/// @param name The name of the flag.
/// @param abbr The abbreviation for the flag.
/// @returns The new flag.
/// @throws ArgumentError If there is already an option with...
Flag addFlag(String name, String abbreviation) => ...
```

#### DO put doc comments before metadata annotations

```dart
// good
/// A button that can be flipped on and off.
@Component(selector: 'toggle')
class ToggleComponent {}

// bad
@Component(selector: 'toggle')
/// A button that can be flipped on and off.
class ToggleComponent {}
```

### 2.3 Markdown

You are allowed to use most Markdown formatting in your doc comments.

#### AVOID using markdown excessively

When in doubt, format less. Words are what matter.

#### AVOID using HTML for formatting

If it's too complex to express in Markdown, you're better off not expressing it.

#### PREFER backtick fences for code blocks

The backtick syntax avoids indentation woes, lets you indicate the code's language, and is consistent with using backticks for inline code.

```dart
// good
/// You can use [CodeBlockExample] like this:
///
/// ```dart
/// var example = CodeBlockExample();
/// print(example.isItGreat); // "Yes."
/// ```

// bad
/// You can use [CodeBlockExample] like this:
///
/// var example = CodeBlockExample();
/// print(example.isItGreat); // "Yes."
```

### 2.4 Writing

#### PREFER brevity

Be clear and precise, but also terse.

#### AVOID abbreviations and acronyms unless they are obvious

Many people don't know what "i.e.", "e.g." and "et al." mean.

#### PREFER using "this" instead of "the" to refer to a member's instance

Using "the" can be ambiguous.

```dart
class Box {
  /// The value this box wraps.
  Object? _value;

  /// Whether this box contains a value.
  bool get hasValue => _value != null;
}
```

---

## 3. Usage

Guidelines for using language features to write maintainable code.

### 3.1 Libraries

These guidelines help you compose your program out of multiple files in a consistent, maintainable way. "Import" covers both `import` and `export` directives.

#### DO use strings in part of directives

The preferred syntax is to use a URI string that points directly to the library file.

```dart
// my_library.dart
library my_library;
part 'some/other/file.dart';

// good - part file uses URI string
part of '../../my_library.dart';

// bad - part file uses library name
part of my_library;
```

#### DON'T import libraries that are inside the src directory of another package

The `src` directory contains libraries private to the package's own implementation.

#### DON'T allow an import path to reach into or out of lib

- Don't use `/lib/` in import paths
- Don't use `../` to escape the `lib` directory
- Use `package:` imports instead

```
// bad - in test/api_test.dart
import '../lib/api.dart';

// good - in test/api_test.dart
import 'package:my_package/api.dart';
```

#### PREFER relative import paths

When an import does not reach across `lib`, prefer using relative imports. They're shorter.

```
// lib/api.dart
import 'src/stuff.dart';
import 'src/utils.dart';

// lib/src/utils.dart
import '../api.dart';
import 'stuff.dart';

// test/api_test.dart
import 'package:my_package/api.dart';
import 'test_utils.dart';
```

### 3.2 Null

#### DON'T explicitly initialize variables to null

If a variable is nullable, it is implicitly initialized to `null` for you.

```dart
// good
Item? bestDeal(List cart) {
  Item? bestItem;
  for (final item in cart) {
    if (bestItem == null || item.price < bestItem.price) {
      bestItem = item;
    }
  }
  return bestItem;
}

// bad
Item? bestDeal(List cart) {
  Item? bestItem = null;
  // ...
}
```

#### DON'T use an explicit default value of null

If you make a nullable parameter optional but don't give it a default value, the language implicitly uses `null` as the default.

```dart
// good
void error([String? message]) {
  stderr.write(message ?? '\n');
}

// bad
void error([String? message = null]) {
  stderr.write(message ?? '\n');
}
```

#### DON'T use true or false in equality operations

Using the equality operator to evaluate a non-nullable boolean expression against a boolean literal is redundant.

```dart
// good
if (nonNullableBool) { ... }
if (!nonNullableBool) { ... }

// bad
if (nonNullableBool == true) { ... }
if (nonNullableBool == false) { ... }
```

To evaluate a nullable boolean expression, use `??` or an explicit `!= null` check.

```dart
// good - null results in false
if (nullableBool ?? false) { ... }

// good - null results in false with type promotion
if (nullableBool != null && nullableBool) { ... }

// bad - static error if null
if (nullableBool) { ... }

// bad - confusing
if (nullableBool == true) { ... }
```

#### AVOID late variables if you need to check whether they are initialized

Dart offers no way to tell if a `late` variable has been initialized. Make the variable non-late and nullable instead.

#### CONSIDER type promotion or null-check patterns for using nullable types

Checking that a nullable variable is not equal to `null` promotes the variable to a non-nullable type. Type promotion is only supported for local variables, parameters, and private final fields.

Use a null-check pattern to confirm a member's value is not null and bind it to a new non-nullable variable.

```dart
class UploadException {
  final Response? response;
  UploadException([this.response]);

  @override
  String toString() {
    if (this.response case var response?) {
      return 'Could not complete upload to ${response.url} '
          '(error code ${response.errorCode}): ${response.reason}.';
    }
    return 'Could not upload (no response).';
  }
}
```

Alternatively, assign the field's value to a local variable.

### 3.3 Strings

#### DO use adjacent strings to concatenate string literals

Simply placing them next to each other does it.

```dart
// good
raiseAlarm(
  'ERROR: Parts of the spaceship are on fire. Other '
  'parts are overrun by martians. Unclear which are which.',
);

// bad
raiseAlarm(
  'ERROR: Parts of the spaceship are on fire. Other ' +
  'parts are overrun by martians. Unclear which are which.',
);
```

#### PREFER using interpolation to compose strings and values

Interpolation is cleaner and shorter than using `+`.

```dart
// good
'Hello, $name! You are ${year - birth} years old.';

// bad
'Hello, ' + name + '! You are ' + (year - birth).toString() + ' y...';
```

#### AVOID using curly braces in interpolation when not needed

If you're interpolating a simple identifier not immediately followed by more alphanumeric text, omit the `{}`.

```dart
// good
var greeting = 'Hi, $name! I love your ${decade}s costume.';

// bad
var greeting = 'Hi, ${name}! I love your ${decade}s costume.';
```

### 3.4 Collections

Dart supports four collection types: lists, maps, queues, and sets.

#### DO use collection literals when possible

Dart has nicer built-in syntax for creating lists, maps, and sets.

```dart
// good
var points = [];
var addresses = {};
var counts = {};

// bad
var addresses = Map();
var counts = Set();
```

Collection literals give you access to the spread operator and control flow operators.

```dart
// good
var arguments = [
  ...options,
  command,
  ...?modeFlags,
  for (var path in filePaths)
    if (path.endsWith('.dart')) path.replaceAll('.dart', '.js'),
];
```

#### DON'T use .length to see if a collection is empty

Use `.isEmpty` and `.isNotEmpty` – they are faster and more readable.

```dart
// good
if (lunchBox.isEmpty) return 'so hungry...';
if (words.isNotEmpty) return words.join(' ');

// bad
if (lunchBox.length == 0) return 'so hungry...';
if (!words.isEmpty) return words.join(' ');
```

#### AVOID using Iterable.forEach() with a function literal

In Dart, the idiomatic way to iterate is using a `for-in` loop.

```dart
// good
for (final person in people) { ... }

// bad
people.forEach((person) { ... });
```

It's fine to use `forEach()` with an existing function, and always OK to use `Map.forEach()`.

#### DON'T use List.from() unless you intend to change the type of the result

`toList()` preserves the type argument of the original object. Use `List.from()` if you want to change the type.

```dart
// good - preserves type
var copy = iterable.toList();

// good - changes type
var ints = List.from(numbers);

// bad - unnecessary and changes type
var copy = List.from(iterable);
```

#### DO use whereType() to filter a collection by type

`whereType()` is concise, produces an `Iterable` of the desired type, and has no unnecessary levels of wrapping.

```dart
// good
var objects = [1, 'a', 2, 'b', 3];
var ints = objects.whereType<int>();

// bad
var ints = objects.where((e) => e is int).cast<int>();
```

#### DON'T use cast() when a nearby operation will do

See if one of the existing transformations can change the type.

```dart
// good
var ints = List<int>.from(stuff);

// bad
var ints = stuff.toList().cast<int>();
```

#### AVOID using cast()

Prefer these options instead:
- Create it with the right type
- Cast the elements on access
- Eagerly cast using `List.from()`

### 3.5 Functions

#### DO use a function declaration to bind a function to a name

Use a function declaration statement instead of binding a lambda to a variable.

```dart
// good
void main() {
  void localFunction() { ... }
}

// bad
void main() {
  var localFunction = () { ... };
}
```

#### DON'T create a lambda when a tear-off will do

When you refer to a function, method, or named constructor without parentheses, Dart creates a tear-off.

```dart
// good
charCodes.forEach(print);
charCodes.forEach(buffer.write);
var strings = charCodes.map(String.fromCharCode);
var buffers = charCodes.map(StringBuffer.new);

// bad
charCodes.forEach((code) { print(code); });
charCodes.forEach((code) { buffer.write(code); });
var strings = charCodes.map((code) => String.fromCharCode(code));
var buffers = charCodes.map((code) => StringBuffer(code));
```

### 3.6 Variables

#### DO follow a consistent rule for var and final on local variables

Most local variables shouldn't have type annotations and should be declared using just `var` or `final`.

Two rules in wide use:
1. Use `final` for local variables that are not reassigned and `var` for those that are
2. Use `var` for all local variables

Pick one and apply it consistently.

#### AVOID storing what you can calculate

Store the minimal amount of data needed. There are no fields to get out of sync because there is only a single source of truth.

```dart
// good
class Circle {
  double radius;
  Circle(this.radius);
  double get area => pi * radius * radius;
  double get circumference => pi * 2.0 * radius;
}

// bad - stores calculated values
class Circle {
  double radius;
  double area;
  double circumference;
  Circle(double radius) : radius = radius,
    area = pi * radius * radius,
    circumference = pi * 2.0 * radius;
}
```

### 3.7 Members

#### DON'T wrap a field in a getter and setter unnecessarily

In Dart, fields and getters/setters are completely indistinguishable. You can expose a field and later wrap it without touching any code that uses it.

```dart
// good
class Box {
  Object? contents;
}

// bad - unnecessary
class Box {
  Object? _contents;
  Object? get contents => _contents;
  set contents(Object? value) {
    _contents = value;
  }
}
```

#### PREFER using a final field to make a read-only property

If outside code should be able to see but not assign to a field, simply mark it `final`.

```dart
// good
class Box {
  final contents = [];
}

// bad - unnecessarily complex
class Box {
  Object? _contents;
  Object? get contents => _contents;
}
```

#### CONSIDER using => for simple members

This style is a good fit for simple members that just calculate and return a value.

```dart
// good
double get area => (right - left) * (bottom - top);
String capitalize(String name) => '${name[0].toUpperCase()}${name.substring(1)}';
```

---

## 4. Design

Design consistent, usable libraries.

### 4.1 Names

#### DO use terms consistently

Use the same name for the same thing throughout your code. If a precedent already exists outside your API, follow that precedent.

```dart
// good
pageCount              // A field.
updatePageCount()      // Consistent with pageCount.
toSomething()          // Consistent with Iterable's toList().
asSomething()          // Consistent with List's asMap().
Point                  // A familiar concept.

// bad
renumberPages()        // Confusingly different from pageCount.
convertToSomething()   // Inconsistent with toX() precedent.
wrappedAsSomething()   // Inconsistent with asX() precedent.
Cartesian              // Unfamiliar to most users.
```

#### AVOID abbreviations

Unless the abbreviation is more common than the unabbreviated term, don't abbreviate.

```dart
// good
pageCount
buildRectangles
IOStream
HttpRequest

// bad
numPages        // "Num" is an abbreviation of "number (of)"
buildRects
InputOutputStream
HypertextTransferProtocolRequest
```

#### PREFER putting the most descriptive noun last

The last word should be the most descriptive of what the thing is.

```dart
// good
pageCount              // A count (of pages).
ConversionSink         // A sink for doing conversions.
ChunkedConversionSink  // A ConversionSink that's chunked.
CssFontFaceRule        // A rule for font faces in CSS.

// bad
numPages               // Not a collection of pages.
CanvasRenderingContext2D // Not a "2D".
RuleFontFaceCss        // Not a CSS.
```

#### CONSIDER making the code read like a sentence

Write some code that uses your API and try to read it like a sentence. Don't add articles and other parts of speech to force literal grammatical correctness.

```dart
// good
if (errors.isEmpty) { ... }
subscription.cancel();
monsters.where((monster) => monster.hasClaws);

// bad
if (errors.empty) { ... }
subscription.toggle();
monsters.filter((monster) => monster.hasClaws);

// too far
if (theCollectionOfErrors.isEmpty) { ... }
monsters.producesANewSequenceWhereEach((monster) => monster.hasClaws);
```

#### PREFER a noun phrase for a non-boolean property or variable

The reader's focus is on what the property is.

```dart
// good
list.length
context.lineWidth
quest.rampagingSwampBeast

// bad
list.deleteItems
```

#### PREFER a non-imperative verb phrase for a boolean property or variable

Boolean names are often used as conditions in control flow.

Good names tend to start with:
- A form of "to be": `isEnabled`, `wasShown`, `willFire`
- An auxiliary verb: `hasElements`, `canClose`, `shouldConsume`, `mustSave`
- An active verb: `ignoresInput`, `wroteFile` (rare, can be ambiguous)

```dart
// good
isEmpty
hasElements
canClose
closesWindow
canShowPopup
hasShownPopup

// bad
empty           // Adjective or verb?
withElements    // Sounds like it might hold elements.
closeable       // Sounds like an interface.
closingWindow   // Returns a bool or a window?
showPopup       // Sounds like it shows the popup.
```

#### CONSIDER omitting the verb for a named boolean parameter

For named boolean parameters, the name is often just as clear without the verb.

```dart
// good
Isolate.spawn(entryPoint, message, paused: false);
var copy = List.from(elements, growable: true);
var regExp = RegExp(pattern, caseSensitive: false);
```

#### PREFER the "positive" name for a boolean property or variable

Prefer the positive or more fundamental one. If your property itself reads like a negation, it's harder for the reader to mentally perform double negation.

```dart
// good
if (socket.isConnected && database.hasData) {
  socket.write(database.read());
}

// bad
if (!socket.isDisconnected && !database.isEmpty) {
  socket.write(database.read());
}
```

**Exception:** With some properties, the negative form is what users overwhelmingly need to use.

#### PREFER an imperative verb phrase for a function or method whose main purpose is a side effect

Members called mainly for their side effect should be named using an imperative verb phrase.

```dart
// good
list.add('element');
queue.removeFirst();
window.refresh();
```

#### PREFER a noun phrase or non-imperative verb phrase for a function or method if returning a value is its primary purpose

If a member is syntactically a method but conceptually a property, name it with a phrase that describes what the member returns.

```dart
// good
var element = list.elementAt(3);
var first = list.firstWhere(test);
var char = string.codeUnitAt(4);
```

This guideline is deliberately softer. Sometimes a method has no side effects but is still simpler to name with a verb phrase like `list.take()` or `string.split()`.

#### CONSIDER an imperative verb phrase for a function or method if you want to draw attention to the work it performs

When the work required to produce a result is important (e.g., networking or file I/O), give the member a verb phrase name that describes that work.

```dart
// good
var table = database.downloadData();
var packageVersions = packageGraph.solveConstraints();
```

#### AVOID starting a function or method name with get

In most cases, the method or function should be a getter with `get` removed from the name.

```dart
// good
breakfastOrder()       // noun phrase
downloadData()         // verb phrase (more precise than "get")

// bad
getBreakfastOrder()
```

#### PREFER naming a method to___() if it copies the object's state to a new object

A conversion method returns a new object containing a copy of almost all of the state of the receiver.

```dart
// good
list.toSet();
stackTrace.toString();
dateTime.toLocal();
```

#### PREFER naming a method as___() if it returns a different representation backed by the original object

A view refers back to the original. Later changes to the original are reflected in the view.

```dart
// good
var map = table.asMap();
var list = bytes.asFloat32List();
var future = subscription.asFuture();
```

#### AVOID describing the parameters in the function's or method's name

The user will see the argument at the call site.

```dart
// good
list.add(element);
map.remove(key);

// bad
list.addElement(element);
map.removeKey(key);
```

However, it can be useful to mention a parameter to disambiguate it from other similarly-named methods:

```dart
// good
map.containsKey(key);
map.containsValue(value);
```

#### DO follow existing mnemonic conventions when naming type parameters

- `E` for the element type in a collection
- `K` and `V` for the key and value types in an associative collection
- `R` for a type used as the return type
- Otherwise, use `T`, `S`, and `U` for generics that have a single type parameter

```dart
// good
class IterableBase<E> { ... }
class List<E> { ... }
class Map<K, V> { ... }
class MapEntry<K, V> { ... }
```

### 4.2 Libraries

A leading underscore (`_`) indicates that a member is private to its library. This is built into the language.

#### PREFER making declarations private

A public declaration is a commitment to support that member. Add `_` if that's not what you intend.

#### CONSIDER declaring multiple classes in the same library

Dart does not tie file organization to class organization. Privacy works at the library level, not the class level.

### 4.3 Classes and Mixins

#### AVOID defining a one-member abstract class when a simple function will do

Dart has first-class functions, closures, and a nice light syntax for using them.

```dart
// good
typedef Predicate = bool Function(E element);

// bad
abstract class Predicate {
  bool test(E element);
}
```

#### AVOID defining a class that contains only static members

Dart has top-level functions, variables, and constants, so you don't need a class just to define something. If you want a namespace, a library is a better fit.

```dart
// good
DateTime mostRecent(List<DateTime> dates) {
  return dates.reduce((a, b) => a.isAfter(b) ? a : b);
}
const _favoriteMammal = 'weasel';

// bad
class DateUtils {
  static DateTime mostRecent(List<DateTime> dates) { ... }
}
class _Favorites {
  static const mammal = 'weasel';
}
```

#### AVOID extending a class that isn't intended to be subclassed

If the author of the class doesn't communicate that it's intended to be subclassed, it's best to assume you should not extend the class.

#### DO use class modifiers to control if your class can be extended

Use `final`, `interface`, or `sealed` to restrict how a class can be extended.

#### AVOID implementing a class that isn't intended to be an interface

Implementing a class's interface is a very tight coupling to that class. Virtually any change to the class will break your implementation.

#### DO use class modifiers to control if your class can be an interface

Use `final`, `base`, or `sealed` to enforce intended usage.

#### PREFER defining a pure mixin or pure class to a mixin class

The `mixin class` declaration is mostly meant to help migrate pre-3.0.0 classes. New code should clearly define the behavior and intention of its declarations.

### 4.4 Constructors

#### CONSIDER making your constructor const if the class supports it

If all fields are final and the constructor does nothing but initialize them, you can make that constructor `const`.

### 4.5 Members

#### PREFER making fields and top-level variables final

State that is not mutable is easier for programmers to reason about.

Consider making a field `late final` if it can't be initialized until after the instance is constructed.

#### DO use getters for operations that conceptually access properties

A getter signals that the operation is "field-like":
- The operation does not take any arguments and returns a result
- The caller cares mostly about the result
- The operation does not have user-visible side effects
- The operation is idempotent

```dart
// good
rectangle.area;
collection.isEmpty;
button.canShow;
dataSet.minimumValue;

// bad - has side effects
stdout.newline;    // Produces output
list.clear;        // Modifies object
```

#### DO use setters for operations that conceptually change properties

---

## Linter Rules Reference

| Rule | Description |
|------|-------------|
| [`camel_case_types`](https://dart.dev/tools/linter-rules/camel_case_types) | Types should use UpperCamelCase |
| [`library_prefixes`](https://dart.dev/tools/linter-rules/library_prefixes) | Import prefixes should use lowercase_with_underscores |
| [`directives_ordering`](https://dart.dev/tools/linter-rules/directives_ordering) | Directives should be in a consistent order |
| [`prefer_mixin`](https://dart.dev/tools/linter-rules/prefer_mixin) | Prefer pure mixin or pure class to mixin class |

---

*Compiled from Dart's official Effective Dart guides: [Style](https://dart.dev/effective-dart/style), [Documentation](https://dart.dev/effective-dart/documentation), [Usage](https://dart.dev/effective-dart/usage), and [Design](https://dart.dev/effective-dart/design).*