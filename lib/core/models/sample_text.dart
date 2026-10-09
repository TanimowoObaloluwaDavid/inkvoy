import 'book.dart' show Book;

/// Generates an always-readable literary preview for books that have no
/// public-domain full text. The prose echoes the book's title and author so
/// the reader is never left at a dead end.
abstract final class SampleText {
  static String forBook(Book book) {
    final title = book.title.trim();
    final author = book.author?.trim().isNotEmpty == true ? book.author!.trim() : 'an author whose name time has nearly kept';
    final a = _article(title.isEmpty ? 'a' : title[0]);

    return '''
Chapter I

Every library is a promise. It stands in a parlor or a narrow hall, in the quiet corner of a sleeping house, and asks only that you sit down beside it. So it is with $a $title, a book that begins, as all good books do, with a reader and a room and a question that has not yet been asked aloud.

This page is a reading preview, written in the spirit of the original — a gentle stand-in while the full edition is fetched. Turn it like any first page: with the certain knowledge that the story you are holding has travelled through more hands than you will ever count.

The story, wherever it truly begins, begins in weather. A morning of the kind that licks gold across the rooftops, or a rain so patient it seems to apologize for arriving. And into that weather walks a figure — lonely, stubborn, or simply in a hurry — carrying a small valise and a larger hope.

That figure is, in a way, every reader. We come to a story the way travellers come to an inn: tired of our own company, and yet unwilling to begin again unless the warmth is genuine. These pages intend to be warm. They intend to let you breathe.

Somewhere beyond this opening, $a $title continues its quiet work of accumulation — incidents, arguments, small victories, doors that close a shade too loudly, letters sent and letters kept. The author, ${_authorName(author)}, knew that a plot is only a scaffold for feeling; the real architecture is the sly way one ordinary hour makes itself unforgettable.

And so we read on. Not because we must, but because somewhere in these paragraphs there is a sentence that will feel like remembering, a line addressed so precisely to you that you will set the book down for a moment, simply to keep it new.

The librarian in the corner turns a page of her own and does not look up. Outside, the rain has stopped or has not stopped; it hardly matters. A reader who has begun a promising book is already somewhere else, standing at the edge of that promise, ready to step in.
''';
  }

  static String _article(String first) {
    final c = first.toLowerCase();
    return 'aeiou'.contains(c) ? 'an' : 'a';
  }

  static String _authorName(String author) {
    final parts = author.split(',').map((p) => p.trim().split(RegExp(r'\s+'))).expand((p) => p).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'our storyteller';
    if (parts.length == 1) return parts.first;
    return parts.take(2).join(' ');
  }
}