import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:truce_calendar/truce_calendar.dart';
import 'package:truce_files/truce_files.dart';
import 'package:truce_markdown/truce_markdown.dart';

import '../../support.dart';

void main() {
  final work = folderAt(Directory('/work'), id: 'work');
  final home = folderAt(Directory('/home'), id: 'home');
  final note = listedFile(work, name: 'a.md');
  final calendar = listedFile(work, name: 'b.ics');
  final noteAtHome = listedFile(home, name: 'c.md');
  final files = [note, calendar, noteAtHome];
  const markdown = MarkdownSupport();
  const calendars = CalendarSupport();

  test('shows every file when nothing is picked', () {
    expect(const FileFilter().of(files), files);
  });

  test('shows the files of the folder picked', () {
    expect(FileFilter(folder: home.id).of(files), [noteAtHome]);
  });

  test('shows the files of the type picked', () {
    expect(FileFilter(type: calendars.type).of(files), [calendar]);
  });

  test('shows the files of both the folder and the type picked', () {
    expect(FileFilter(folder: work.id, type: markdown.type).of(files), [note]);
  });

  test('a file of no known type shows only while every type does', () {
    expect(const FileFilter().shows(work.id, null), isTrue);
    expect(FileFilter(type: markdown.type).shows(work.id, null), isFalse);
  });
}
