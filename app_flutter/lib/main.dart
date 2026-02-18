import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

void main() => runApp(const CustodiApp());

class CustodiApp extends StatelessWidget {
  const CustodiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'I Custodi del DNA',
      theme: ThemeData(useMaterial3: true),
      home: const NewsPage(),
    );
  }
}

class WpPost {
  final int id;
  final String title;
  final String excerpt;
  final DateTime date;
  final String link;

  WpPost({
    required this.id,
    required this.title,
    required this.excerpt,
    required this.date,
    required this.link,
  });

  factory WpPost.fromJson(Map<String, dynamic> json) {
    String plain(String html) =>
        html.replaceAll(RegExp(r'<[^>]*>'), '').replaceAll('&nbsp;', ' ').trim();

    return WpPost(
      id: json['id'] as int,
      title: plain((json['title']?['rendered'] ?? '').toString()),
      excerpt: plain((json['excerpt']?['rendered'] ?? '').toString()),
      date: DateTime.tryParse((json['date'] ?? '').toString()) ?? DateTime.now(),
      link: (json['link'] ?? '').toString(),
    );
  }
}

class NewsPage extends StatefulWidget {
  const NewsPage({super.key});

  @override
  State<NewsPage> createState() => _NewsPageState();
}

class _NewsPageState extends State<NewsPage> {
  static const _base = 'https://www.icustodideldna.it';
  late Future<List<WpPost>> _future;

  @override
  void initState() {
    super.initState();
    _future = fetchPosts();
  }

  Future<List<WpPost>> fetchPosts() async {
    final uri = Uri.parse('$_base/wp-json/wp/v2/posts?per_page=10');
    final res = await http.get(uri, headers: {'Accept': 'application/json'});
    if (res.statusCode != 200) {
      throw Exception('WordPress API error: ${res.statusCode}\n${res.body}');
    }
    final list = (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
    return list.map(WpPost.fromJson).toList();
  }

  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('d MMM yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Text('News — I Custodi del DNA'),
        actions: [
          IconButton(
            tooltip: 'Apri sito',
            onPressed: () => _open('$_base/'),
            icon: const Icon(Icons.public),
          )
        ],
      ),
      body: FutureBuilder<List<WpPost>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Errore nel caricare i post.'),
                  const SizedBox(height: 8),
                  Text(snapshot.error.toString()),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => setState(() => _future = fetchPosts()),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Riprova'),
                  ),
                ],
              ),
            );
          }

          final posts = snapshot.data ?? const <WpPost>[];
          if (posts.isEmpty) {
            return const Center(child: Text('Nessun articolo trovato.'));
          }

          return RefreshIndicator(
            onRefresh: () async => setState(() => _future = fetchPosts()),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(12),
              itemCount: posts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final p = posts[i];
                return Card(
                  child: ListTile(
                    title: Text(
                      p.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 6),
                        Text(df.format(p.date)),
                        if (p.excerpt.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            p.excerpt,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _open(p.link),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
