import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';

class LibraryCubit extends Cubit<int> {
  LibraryCubit(this._box) : super(0);
  final Box<dynamic> _box;

  List<String> get myList =>
      List<String>.from(_box.get('my_list', defaultValue: <String>[]));
  Map<String, int> get progress => Map<String, int>.from(
    _box.get('progress', defaultValue: <String, int>{}),
  );
  List<String> get history =>
      List<String>.from(_box.get('history', defaultValue: <String>[]));
  List<String> get downloads =>
      List<String>.from(_box.get('downloads', defaultValue: <String>[]));
  bool contains(String id) => myList.contains(id);

  Future<void> addToHistory(String id) async {
    final current = history..remove(id);
    current.insert(0, id);
    await _box.put('history', current.take(100).toList());
    emit(state + 1);
  }

  Future<void> toggleMyList(String id) async {
    final current = myList;
    current.contains(id) ? current.remove(id) : current.add(id);
    await _box.put('my_list', current);
    emit(state + 1);
  }

  Future<void> saveProgress(String id, int seconds) async {
    final current = progress;
    current[id] = seconds;
    await _box.put('progress', current);
    emit(state + 1);
  }
}
