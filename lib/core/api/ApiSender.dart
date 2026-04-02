import 'package:dio/dio.dart';
import '../../features/sms_import/data/sms_queue.dart';

class ApiSender {
  static final _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {"Content-Type": "application/json"},
      validateStatus: (_) => true, // ✅ don't throw on 4xx/5xx
    ),
  );

  static const endpoint =
      "https://mobile.smbet.info/api/MobileMoneySms/ForwardedSms";

  static Future<void> tryFlushQueue() async {
    final pending = await SmsQueue.pending(limit: 50);

    for (final m in pending) {
      final key = m["_key"];

      try {
        await SmsQueue.markTry(key);

        final raw = Map<String, dynamic>.from(m)..remove("_key");

        final payload = {
          "DeviceId": raw["deviceId"],
          "From": raw["from"],
          "Body": raw["body"],
          "SmsDate": raw["smsDate"],
          "ProviderHint": raw["providerHint"],
        };

        print("📤 Forward payload: $payload");

        final res = await _dio.post(endpoint, data: payload);

        print("📥 Forward status=${res.statusCode}");
        print("📥 Forward body=${res.data}");

        final code = res.statusCode ?? 0;
        if (code >= 200 && code < 300) {
          await SmsQueue.markSent(key);
          print("✅ Forwarded and marked sent");
        } else {
          print("❌ Forward failed HTTP=$code");
          break;
        }
      } on DioException catch (e) {
        print("❌ DioException type=${e.type}");
        print("❌ DioException status=${e.response?.statusCode}");
        print("❌ DioException body=${e.response?.data}");
        print("❌ DioException message=${e.message}");
        break;
      } catch (e) {
        print("❌ Forward exception: $e");
        break;
      }
    }
  }
}