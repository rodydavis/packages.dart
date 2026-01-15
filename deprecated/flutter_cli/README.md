## Flutter CLI

[![Pub Package](https://img.shields.io/pub/v/ngflutter.svg)](https://pub.dartlang.org/packages/ngflutter)
[![Build Status](https://travis-ci.org/google/ngflutter.svg?branch=master)](https://travis-ci.org/google/ngflutter)

A command line interface for [Flutter][webdev_flutter].
It can scaffold a skeleton Flutter project, component, and test with
[page object][page_object].

## Installation

To install:

```bash
pub global activate ngflutter
pub global activate webdev
```

To update:

```bash
pub global activate ngflutter
pub global activate webdev
```

## Usage

```bash
ngflutter help
```

For help on specific command, run `ngflutter help [command name]`
For example:

```bash
ngflutter help generate test
```

will show how to use command `generate test`.

### Generating Flutter project

```bash
ngflutter new project_name
cd project_name
pub get
webdev serve
```

Navigate to `http://localhost:8080` to visit the project you just built.
Command following will assume that you are in the root directory of
the project.

### Generating component

```bash
ngflutter generate component AnotherComponent
```
This command will generate component under folder `lib/`.
You can use option `-p` to change the folder.


### Generating test

```bash
ngflutter generate test lib/app_component.dart
```

Command above will generate 2 files. One is page object file
and the other one is test file.
Test generated is using [flutter_test][pub_flutter_test]
and [test][pub_test] package.

Use command

```bash
pub run build_runner test --fail-on-severe -- -p chrome
```

to run generated test with Chrome.

[webdev_flutter]: https://webdev.dartlang.org/flutter
[page_object]: https://martinfowler.com/bliki/PageObject.html
[pub_flutter_test]: https://pub.dartlang.org/packages/flutter_test
[pub_test]: https://pub.dartlang.org/packages/test
