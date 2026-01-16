import 'package:flutter/material.dart';

import 'source.dart';

class TaggedDataView<T> extends StatefulWidget {
  const TaggedDataView({
    Key key,
    @required this.dataSource,
    this.tagViewWidth = 220,
    this.listViewWidth = 280,
    this.emptyBuilder,
    this.detailBuilder,
    this.actions,
  }) : super(key: key);

  final TaggedDataTableSource<T> dataSource;
  final double listViewWidth, tagViewWidth;
  final Widget Function(BuildContext context) emptyBuilder;
  final Widget Function(BuildContext context, T item, int index) detailBuilder;
  final List<Widget> actions;

  @override
  _TaggedDataViewState<T> createState() => _TaggedDataViewState<T>();
}

class _TaggedDataViewState<T> extends State<TaggedDataView<T>> {
  @override
  void initState() {
    super.initState();
    widget.dataSource.addListener(_handleSourceChange);
  }

  @override
  void dispose() {
    widget.dataSource.removeListener(_handleSourceChange);
    super.dispose();
  }

  void _handleSourceChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final source = widget.dataSource;
    final tags = widget.dataSource.allTags;
    final folders = tags.where((e) => e.contains('/')).toList();
    final other = tags
        .where((e) => !folders.map((e) => e.split('/').first).contains(e))
        .toList();
    final allTags = [...folders, ...other].toSet().toList();
    allTags.sort();
    final emptyBuilder = () {
      return widget.emptyBuilder(context);
          return Scaffold(
        appBar: AppBar(
          centerTitle: false,
          title: Text('Details'),
        ),
        body: Center(
          child: Text('No Item Selected'),
        ),
      );
    };
    final detailBuilder = (int index) {
      final T item = widget.dataSource.items[index];
      return widget.detailBuilder(context, item, index);
          return Scaffold(
        appBar: AppBar(
          centerTitle: false,
          title: Text('Details'),
        ),
        body: Center(
          child: Text(item.toString()),
        ),
      );
    };
    final tagsBuilder = (Function(BuildContext context) onTap) {
      return Scrollbar(
        child: ListView(
          children: [
            ListTile(
              selected: widget.dataSource.selectedTag == null,
              onTap: () {
                widget.dataSource.selectTag(null);
                onTap(context);
              },
              leading: Icon(Icons.list),
              title: Text('all'),
            ),
            for (var i = 0; i < allTags.length; i++)
              buildTag(allTags[i], folders.contains(allTags[i]), onTap),
          ],
        ),
      );
    };
    final listBuilder = (Function(int index) onTap) {
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 4,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Search',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (val) {
                      widget.dataSource.onSearch(val);
                      if (mounted) setState(() {});
                    },
                  ),
                )
              ],
            ),
          ),
          Expanded(
            child: Scrollbar(
              child: ListView.builder(
                itemCount: source.rowsForTag.keys.length,
                itemBuilder: (context, index) {
                  final key = source.rowsForTag.keys.toList()[index];
                  final row = source.rowsForTag[key];
                  return ListTile(
                    title: row.cells[0].child,
                    subtitle: row.cells[1].child,
                    selected: row.selected,
                    onTap: () => onTap(key),
                  );
                },
              ),
            ),
          ),
        ],
      );
    };
    return LayoutBuilder(
      builder: (context, dimens) {
        if (dimens.maxWidth >= 720) {
          return Row(
            children: [
              Container(
                width: widget.tagViewWidth + widget.listViewWidth,
                child: Scaffold(
                  appBar: AppBar(
                    centerTitle: false,
                    title: Text(widget.dataSource.selectedTag ?? 'all'),
                    actions: widget.actions ?? [],
                  ),
                  body: Row(
                    children: [
                      Container(
                        width: widget.tagViewWidth,
                        child: tagsBuilder((context) => {}),
                      ),
                      Container(
                        width: widget.listViewWidth,
                        child: listBuilder((index) {
                          final row = widget.dataSource.getRow(index);
                          row.onSelectChanged(!row.selected);
                          widget.dataSource.clearSelection(index);
                        }),
                      ),
                    ],
                  ),
                ),
              ),
              VerticalDivider(width: 0),
              Expanded(
                child: widget.dataSource.selectedRowCount == 0
                    ? emptyBuilder()
                    : detailBuilder(widget.dataSource.selected.last),
              ),
            ],
          );
        }
        return Scaffold(
          appBar: AppBar(
            centerTitle: false,
            title: Text(widget.dataSource.selectedTag ?? 'all'),
            actions: widget.actions ?? [],
          ),
          drawer: Drawer(
            child: tagsBuilder((context) {
              Navigator.of(context).maybePop();
            }),
          ),
          body: listBuilder((index) {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => detailBuilder(index),
            ));
          }),
        );
      },
    );
  }

  Widget buildTag(
    String tag,
    bool folder,
    Function(BuildContext context) onTap,
  ) {
    if (folder) {
      return TagFolder<T>(
        dataSource: widget.dataSource,
        tag: tag,
      );
    }
    return Builder(
      builder: (context) {
        return ListTile(
          selected: widget.dataSource.selectedTag == tag,
          onTap: () {
            widget.dataSource.selectTag(tag);
            onTap(context);
          },
          leading: widget.dataSource.getIconForTag(tag),
          title: Text(tag),
        );
      },
    );
  }
}

class TagFolder<T> extends StatefulWidget {
  const TagFolder({
    Key key,
    @required this.tag,
    @required this.dataSource,
  }) : super(key: key);
  final String tag;
  final TaggedDataTableSource<T> dataSource;

  @override
  _TagFolderState createState() => _TagFolderState();
}

class _TagFolderState extends State<TagFolder> {
  bool _expanded = false;
  @override
  Widget build(BuildContext context) {
    final name = widget.tag.split('/').first.trim();
    return Column(
      children: [
        ListTile(
          selected: widget.dataSource.selectedTag == name,
          onTap: () => widget.dataSource.selectTag(name),
          leading: widget.dataSource.getIconForTag(name),
          title: Text(name),
          trailing: IconButton(
            icon: Icon(_expanded
                ? Icons.keyboard_arrow_up
                : Icons.keyboard_arrow_down),
            onPressed: () {
              if (mounted)
                setState(() {
                  _expanded = !_expanded;
                });
            },
          ),
        ),
        if (_expanded)
          ...widget.dataSource.allTags
              .where((e) => e.contains('$name/'))
              .map((e) => Container(
                    margin: const EdgeInsets.only(left: 20),
                    child: ListTile(
                      selected: widget.dataSource.selectedTag == widget.tag,
                      onTap: () => widget.dataSource.selectTag(widget.tag),
                      leading:
                          widget.dataSource.getIconForTag(e.split('/').last),
                      title: Text(e.split('/').last),
                    ),
                  ))
              .toList()
      ],
    );
  }
}
