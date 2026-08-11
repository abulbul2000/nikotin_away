import 'dart:convert';
import 'package:http/http.dart' as http;

Future<String> sendMessageToAI(String message) async {
  final response = await http.post(
    Uri.parse("http://localhost:3000/api/chat"),
    headers: {"Content-Type": "application/json"},
    body: jsonEncode({"message": message}),
  );

  final data = jsonDecode(response.body);
  return data["reply"];
}
