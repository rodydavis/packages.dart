import 'package:flutter/material.dart';

class DataSource<T> extends DataTableSource {
  DataSource(this._items);
  final List<T> _items;

  @override
  int get selectedRowCount => selected.length;
  final Set<int> selected = {};

  String _search = '';
  String get search => this._search;
  void onSearch(String val) {
    _search = val;
    this.notifyListeners();
  }

  @override
  DataRow getRow(int index) {
    final item = items[index];
    List<DataCell> cells = <DataCell>[];
    if (item is Map) {
      cells = item.values.map((e) => DataCell(Text(e.toString()))).toList();
    } else {
      cells = [DataCell(Text(item.toString()))];
    }
    return DataRow(
      selected: selected.contains(index),
      cells: cells,
      onSelectChanged: (val) {
        if (val) {
          selected.add(index);
        } else {
          selected.remove(index);
        }
        this.notifyListeners();
      },
    );
  }

  void clearSelection([int skipIndex]) {
    final _past = [...selected];
    for (final idx in _past) {
      if (idx == skipIndex) continue;
      this.getRow(idx).onSelectChanged(false);
      this.selected.remove(idx);
    }
    this.notifyListeners();
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => items.length;

  List<T> get items => this._items ?? [];
}
