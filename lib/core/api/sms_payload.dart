Map<String, dynamic> buildForwardedSmsPayload({
  required String deviceId,
  required String from,
  required String body,
  DateTime? smsDate,
  String? providerHint,
}) {
  return {
    "deviceId": deviceId,
    "from": from,
    "body": body,
    "smsDate": smsDate?.toUtc().toIso8601String(),
    "providerHint": providerHint,
  };
}