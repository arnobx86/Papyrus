import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  final apiKey = 're_9vNeMKyk_Jp223UJhKFvKaTT1V4vjNJrq';
  final to = 'arnobpappu2002@gmail.com'; // Testing with user's likely email
  
  print('Testing Resend API...');
  
  final response = await http.post(
    Uri.parse('https://api.resend.com/emails'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiKey',
    },
    body: jsonEncode({
      'from': 'Papyrus <papyrus@arnob.pro.bd>',
      'to': [to],
      'subject': 'Test Email - Papyrus',
      'html': '<strong>If you see this, the API key and domain are WORKING!</strong>',
    }),
  );

  print('Status Code: ${response.statusCode}');
  print('Response: ${response.body}');
}
