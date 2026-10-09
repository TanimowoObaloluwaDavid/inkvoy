import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/book.dart';

/// Payload for the book-detail route (book + hero tag so cover flights never
/// collide across shell tabs).
class BookRouteArgs {
  final Book book;
  final String tag;
  const BookRouteArgs(this.book, this.tag);
}

String coverTag(String prefix, String key) => '$prefix:$key';

void pushBook(BuildContext context, Book book, {String prefix = 'h'}) {
  context.push('/book/${book.key}', extra: BookRouteArgs(book, coverTag(prefix, book.key)));
}

void pushReader(BuildContext context, Book book) {
  context.push('/reader/${book.key}', extra: book);
}