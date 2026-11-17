import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:moviepilot_mobile/modules/search/models/omnihub_release_log.dart';

class ChangelogPage extends StatefulWidget {
  const ChangelogPage({super.key});

  @override
  State<ChangelogPage> createState() => _ChangelogPageState();
}

class _ChangelogPageState extends State<ChangelogPage> {
  int _selectedTabIndex = 0;
  String? _upstreamContent;
  bool _isLoadingUpstream = true;

  @override
  void initState() {
    super.initState();
    _loadUpstreamChangelog();
  }

  Future<void> _loadUpstreamChangelog() async {
    try {
      final text = await rootBundle.loadString('CHANGELOG.md');
      if (!mounted) return;
      setState(() {
        _upstreamContent = text;
        _isLoadingUpstream = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _upstreamContent = null;
        _isLoadingUpstream = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('发布与更新日志'),
        centerTitle: false,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: SizedBox(
              width: double.infinity,
              child: CupertinoSlidingSegmentedControl<int>(
                groupValue: _selectedTabIndex,
                children: const {
                  0: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      'OmniHub 发版记录',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  1: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      '上游官方日志',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                },
                onValueChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedTabIndex = val);
                  }
                },
              ),
            ),
          ),
          Expanded(
            child: _selectedTabIndex == 0
                ? _buildOmniHubReleases(context)
                : _buildUpstreamChangelog(context),
          ),
        ],
      ),
    );
  }

  Widget _buildOmniHubReleases(BuildContext context) {
    final theme = Theme.of(context);
    final releases = OmniHubReleaseHistory.releases;

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      itemCount: releases.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final item = releases[index];
        final isLatest = index == 0;
        final typeColor = item.type.color;

        return Container(
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isLatest
                  ? typeColor.withValues(alpha: 0.45)
                  : theme.dividerColor.withValues(alpha: 0.18),
              width: isLatest ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        item.type.icon,
                        size: 20,
                        color: typeColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.title,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (isLatest) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: CupertinoColors.systemOrange
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: CupertinoColors.systemOrange
                                          .withValues(alpha: 0.35),
                                    ),
                                  ),
                                  child: const Text(
                                    '最新',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: CupertinoColors.systemOrange,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                item.version,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 1.5,
                                ),
                                decoration: BoxDecoration(
                                  color: typeColor.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  item.displayTag,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: typeColor,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                item.date,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  item.summary,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 13,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                  ),
                ),
                if (item.tags.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: item.tags.map((tag) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2.5,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '#$tag',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.7),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: item.highlights.map((point) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 3.5),
                              child: Icon(
                                Icons.check_circle_rounded,
                                size: 13,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                point,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 12.5,
                                  height: 1.4,
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.85),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildUpstreamChangelog(BuildContext context) {
    if (_isLoadingUpstream) {
      return const Center(child: CupertinoActivityIndicator());
    }
    final content = _upstreamContent;
    if (content == null || content.trim().isEmpty) {
      return Center(
        child: Text(
          '暂无上游更新日志',
          style: TextStyle(color: Theme.of(context).colorScheme.secondary),
        ),
      );
    }
    final sections = _parseSections(content);
    if (sections.isEmpty) {
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          MarkdownBody(
            data: content,
            selectable: true,
            styleSheet: _markdownStyle(context),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      itemCount: sections.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final section = sections[index];
        return Card(
          margin: EdgeInsets.zero,
          child: ExpansionTile(
            initiallyExpanded: index == 0,
            title: Text(
              section.title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            tilePadding: const EdgeInsets.symmetric(horizontal: 14),
            children: [
              MarkdownBody(
                data: section.body,
                selectable: true,
                styleSheet: _markdownStyle(context),
              ),
            ],
          ),
        );
      },
    );
  }

  List<_ChangelogSection> _parseSections(String markdown) {
    final lines = markdown.split('\n');
    final sections = <_ChangelogSection>[];
    String? currentTitle;
    final currentBody = <String>[];

    void flushCurrent() {
      if (currentTitle == null) return;
      final body = currentBody.join('\n').trim();
      if (body.isNotEmpty) {
        sections.add(_ChangelogSection(title: currentTitle, body: body));
      }
      currentBody.clear();
    }

    for (final rawLine in lines) {
      final line = rawLine.trimRight();
      if (line.startsWith('## ')) {
        flushCurrent();
        currentTitle = line.substring(3).trim();
        continue;
      }
      if (currentTitle != null) {
        currentBody.add(line);
      }
    }
    flushCurrent();
    return sections;
  }

  MarkdownStyleSheet _markdownStyle(BuildContext context) {
    return MarkdownStyleSheet(
      p: const TextStyle(height: 1.6, fontSize: 13.5),
      h1: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
      h2: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      h3: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      listBullet: TextStyle(
        fontSize: 13.5,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

class _ChangelogSection {
  const _ChangelogSection({required this.title, required this.body});

  final String title;
  final String body;
}
