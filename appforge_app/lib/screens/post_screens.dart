import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';

import '../core/i18n.dart';

import '../core/format.dart';
import '../models/models.dart';
import '../services/repository.dart';
import '../widgets/common.dart';

class PostCard extends StatelessWidget {
  final Post post;
  final bool vertical;
  const PostCard({super.key, required this.post, this.vertical = false});

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(post.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w600)),
        SizedBox(height: 4),
        Text(formatDate(post.date), style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        if (!vertical) ...[
          SizedBox(height: 4),
          Text(post.excerpt, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
        ],
      ],
    );
    return Material(
      color: surface,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PostDetailScreen(postId: post.id, preview: post))),
        child: vertical
            ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                NetImage(post.image, height: 120),
                Padding(padding: EdgeInsets.all(10), child: text),
              ])
            : Row(children: [
                NetImage(post.image, width: 100, height: 90),
                Expanded(child: Padding(padding: EdgeInsets.all(10), child: text)),
              ]),
      ),
    );
  }
}

class PostsScreen extends StatefulWidget {
  final bool isTab;
  const PostsScreen({super.key, this.isTab = false});

  @override
  State<PostsScreen> createState() => _PostsScreenState();
}

class _PostsScreenState extends State<PostsScreen> {
  final List<Post> _posts = [];
  int _page = 1;
  int _totalPages = 1;
  bool _loading = false;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) _load();
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading || (!reset && _page > _totalPages)) return;
    if (reset) {
      _page = 1;
      _totalPages = 1;
    }
    setState(() => _loading = true);
    try {
      final res = await Repo.posts(page: _page);
      if (!mounted) return;
      setState(() {
        if (reset) _posts.clear();
        _posts.addAll(res.items);
        _totalPages = res.totalPages;
        _page++;
      });
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('Blog'))),
      body: _posts.isEmpty && _loading
          ? LoadingView()
          : _posts.isEmpty
              ? MessageView(icon: Icons.article_outlined, title: tr('No posts yet'))
              : RefreshIndicator(
                  onRefresh: () => _load(reset: true),
                  child: ListView.separated(
                    controller: _scroll,
                    padding: EdgeInsets.all(16),
                    itemCount: _posts.length + (_loading ? 1 : 0),
                    separatorBuilder: (_, __) => SizedBox(height: 12),
                    itemBuilder: (_, i) => i >= _posts.length ? LoadingView() : PostCard(post: _posts[i]),
                  ),
                ),
    );
  }
}

class PostDetailScreen extends StatefulWidget {
  final int postId;
  final Post? preview;
  const PostDetailScreen({super.key, required this.postId, this.preview});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  late final Future<Post> _future = Repo.post(widget.postId);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: FutureBuilder<Post>(
        future: _future,
        builder: (context, snap) {
          final post = snap.data ?? widget.preview;
          if (post == null) {
            return snap.hasError ? MessageView.error(snap.error) : LoadingView();
          }
          return ListView(
            children: [
              if (post.image.isNotEmpty) NetImage(post.image, height: 220, width: double.infinity),
              Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(post.title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                    SizedBox(height: 6),
                    Text('${post.author} · ${formatDate(post.date)}', style: TextStyle(color: Colors.grey.shade600)),
                    SizedBox(height: 16),
                    if (snap.data == null) LoadingView() else HtmlWidget(post.content, textStyle: TextStyle(height: 1.6, fontSize: 15)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
