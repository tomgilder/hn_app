import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:hn_app/src/article.dart';
import 'package:hn_app/src/favorites.dart';
import 'package:hn_app/src/notifiers/hn_api.dart';
import 'package:hn_app/src/notifiers/prefs.dart';
import 'package:hn_app/src/serializers.dart';
import 'package:hn_app/src/widgets/headline.dart';
import 'package:hn_app/src/widgets/loading_info.dart';
import 'package:hn_app/src/widgets/request.dart';
import 'package:hn_app/src/widgets/search.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        Provider<LoadingTabsCount>(
          builder: (_) => LoadingTabsCount(),
          dispose: (_, value) => value.dispose(),
        ),
        Provider<MyDatabase>(builder: (_) => MyDatabase()),
        ChangeNotifierProvider(
          builder: (context) => HackerNewsNotifier(
                // TODO(filiph): revisit when ProxyProvider lands
                // https://github.com/rrousselGit/provider/issues/46
                Provider.of<LoadingTabsCount>(context, listen: false),
              ),
        ),
        ChangeNotifierProvider(builder: (_) => PrefsNotifier()),
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  static const primaryColor = Colors.white;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
          primaryColor: primaryColor,
          scaffoldBackgroundColor: primaryColor,
          canvasColor: Colors.black,
          textTheme: Theme.of(context).textTheme.copyWith(
              caption: TextStyle(color: Colors.white54),
              subhead: TextStyle(fontFamily: 'Garamond', fontSize: 10.0))),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();

  @override
  void initState() {
    _pageController.addListener(_handlePageChange);
    super.initState();
  }

  @override
  void dispose() {
    _pageController.removeListener(_handlePageChange);
    super.dispose();
  }

  void _handlePageChange() {
    setState(() {
      _currentIndex = _pageController.page.round();
    });
  }

  @override
  Widget build(BuildContext context) {
    final hn = Provider.of<HackerNewsNotifier>(context);
    final tabs = hn.tabs;

    return Scaffold(
      appBar: AppBar(
        title: Headline(
          text: tabs[_currentIndex].name,
          index: _currentIndex,
        ),
        // leading: Consumer<LoadingTabsCount>(
        //     builder: (context, loading, child) => LoadingInfo(loading)),
        elevation: 0.0,
        actions: [
          IconButton(
            icon: Icon(Icons.search),
            onPressed: () async {
              var result = await showSearch(
                context: context,
                delegate: ArticleSearch(UnmodifiableListView([])), //hn.allArticles),
              );
              if (result != null) {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => HackerNewsWebPage(result.url)));
              }
            },
          ),
        ],
        // TODO: loading value -- why is it never not 1?
        // TODO: Make an iconButton that opens a drawer because
        // Scaffold hard-codes the drawer behavior.
        // TODO: Make a favorites page.
        leading: Consumer<LoadingTabsCount>(builder: (context, loading, child) {
          bool isLoading = loading.value > 0;
          print(loading.value);
          //return LoadingInfo(loading);
          return AnimatedSwitcher(
            duration: Duration(milliseconds: 500),
            child: isLoading
                ? LoadingInfo(loading)
                : Drawer(
                    child: Container(
                        color: Colors.white,
                        height: 300,
                        child: Text('favorites page'))),
          );
        }),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: tabs.length,
        itemBuilder: (context, index) => ChangeNotifierProvider.value(
              notifier: tabs[index],
              child: _TabPage(tabs[index]),
            ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        items: [
          for (final tab in tabs)
            BottomNavigationBarItem(
              title: Text(tab.name),
              icon: Icon(tab.icon),
            )
        ],
        onTap: (index) {
          _pageController.animateToPage(index,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic);
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}

class _Item extends StatelessWidget {
  final Article article;
  final PrefsNotifier prefs;

  const _Item({
    Key key,
    @required this.article,
    @required this.prefs,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final prefs = Provider.of<PrefsNotifier>(context);
    var myDatabase = Provider.of<MyDatabase>(context);
    assert(article.title != null);
    return Padding(
      key: PageStorageKey(article.title),
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 12.0),
      child: Column(
        children: <Widget>[
          ExpansionTile(
            leading: StreamBuilder<bool>(
                stream: myDatabase.isFavorite(article.id),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data) {
                    return IconButton(
                        icon: Icon(Icons.star),
                        onPressed: () => myDatabase.removeFavorite(article.id));
                  }
                  return IconButton(
                      icon: Icon(Icons.star_border),
                      onPressed: () => myDatabase.addFavorite(article));
                }),
            title: Text(article.title, style: TextStyle(fontSize: 24.0)),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: <Widget>[
                        FlatButton(
                          onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (BuildContext context) =>
                                      HackerNewsCommentPage(article.id),
                                ),
                              ),
                          child: Text('${article.descendants} comments'),
                        ),
                        SizedBox(width: 16.0),
                        IconButton(
                          icon: Icon(Icons.launch),
                          onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) =>
                                      HackerNewsWebPage(article.url))),
                        )
                      ],
                    ),
                    prefs.showWebView
                        ? Container(
                            height: 200,
                            child: WebView(
                              javascriptMode: JavascriptMode.unrestricted,
                              initialUrl: article.url,
                              gestureRecognizers: Set()
                                ..add(Factory<VerticalDragGestureRecognizer>(
                                    () => VerticalDragGestureRecognizer())),
                            ),
                          )
                        : Container(),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TabPage extends StatelessWidget {
  _TabPage(this.tab, {Key key}) : super(key: key);

  final HackerNewsTab tab;

  static const _baseUrl = 'https://hacker-news.firebaseio.com/v0/';
  String get partUrl => tab.storiesType == StoriesType.topStories ? 'top' : 'new';
  String get storiesUrl => '$_baseUrl${partUrl}stories.json';

  @override
  Widget build(BuildContext context) {

    return RequestBuilder<List<int>>(
      request: Get(storiesUrl),
      map: (x) => List<int>.from(x).take(10).toList(),
      builder: (_, List<int> articleIds) {

        return MultiRequestBuilder<Article>(
          requests: articleIds.map((id) => Get("${_baseUrl}item/$id.json")),
          map: (x) => standardSerializers.deserializeWith(Article.serializer, x),
          filter: (x) => x.where((a) => a.title != null),
          builder: (BuildContext context, List<Article> articles) {

            return RefreshIndicator(
              color: Colors.white,
              backgroundColor: Colors.black,
              onRefresh: (context.ancestorStateOfType(TypeMatcher<RequestBuilderState>()) as RequestBuilderState).reload,
              child: ListView(
                key: PageStorageKey(tab),
                children: [
                  for (final article in articles)
                    _Item(
                      article: article,
                      prefs: Provider.of<PrefsNotifier>(context),
                    )
                ],
              ),
            );
          }
        );
      }
    );
  }
}

class HackerNewsWebPage extends StatelessWidget {
  HackerNewsWebPage(this.url);

  final String url;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Web Page'),
      ),
      body: WebView(
        initialUrl: url,
        javascriptMode: JavascriptMode.unrestricted,
      ),
    );
  }
}

class HackerNewsCommentPage extends StatelessWidget {
  final int id;

  HackerNewsCommentPage(this.id);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Comments'),
      ),
      body: WebView(
        initialUrl: 'https://news.ycombinator.com/item?id=$id',
        javascriptMode: JavascriptMode.unrestricted,
      ),
    );
  }
}