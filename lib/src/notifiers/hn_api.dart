import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hn_app/src/article.dart';

/// A global cache of articles.
Map<int, Article> _cachedArticles = {};

class HackerNewsApiError extends Error {
  final String message;

  HackerNewsApiError(this.message);
}

/// The number of tabs that are currently loading.
class LoadingTabsCount extends ValueNotifier<int> {
  LoadingTabsCount() : super(0);
}

/// This class encapsulates the app's communication with the Hacker News API
/// and which articles are fetched in which [tabs].
class HackerNewsNotifier with ChangeNotifier {
  List<HackerNewsTab> _tabs;

  HackerNewsNotifier(LoadingTabsCount loading) {
    _tabs = [
      HackerNewsTab(
        StoriesType.topStories,
        'Top Stories',
        Icons.arrow_drop_up,
        loading,
      ),
      HackerNewsTab(
        StoriesType.newStories,
        'New Stories',
        Icons.new_releases,
        loading,
      ),
    ];
  }

  /// Articles from all tabs. De-duplicated.
  // UnmodifiableListView<Article> get allArticles => UnmodifiableListView(
      // _tabs.expand((tab) => tab.articles).toSet().toList(growable: false));

  UnmodifiableListView<HackerNewsTab> get tabs => UnmodifiableListView(_tabs);
}

class HackerNewsTab with ChangeNotifier {
  final StoriesType storiesType;

  final String name;

  final IconData icon;

  final LoadingTabsCount loadingTabsCount;

  HackerNewsTab(this.storiesType, this.name, this.icon, this.loadingTabsCount);
}

enum StoriesType {
  topStories,
  newStories,
}