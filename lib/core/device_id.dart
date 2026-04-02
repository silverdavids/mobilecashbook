import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

class DeviceId {
  static const _boxName = "device_box";
  static const _key = "device_id";

  static Future<String> getOrCreate() async {
    final box = await Hive.openBox(_boxName);
    final existing = box.get(_key) as String?;
    if (existing != null && existing.isNotEmpty) return existing;

    final id = const Uuid().v4();
    await box.put(_key, id);
    return id;
  }
}