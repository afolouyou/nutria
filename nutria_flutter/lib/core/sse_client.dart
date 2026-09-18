import 'dart:async';
import 'dart:convert';
import 'dart:io';

const String sseBaseUrl = 'https://nutria.shares.zrok.io';
const String chatStreamPath = '/api/chat/stream';

class SSEEvent {
  final String type;
  final String? text;
  final Map<String, dynamic>? data;

  const SSEEvent({required this.type, this.text, this.data});

  @override
  String toString() => 'SSEEvent(type: $type, text: $text)';
}

class SSEClient {
  final String baseUrl;

  SSEClient({this.baseUrl = sseBaseUrl});

  Stream<SSEEvent> streamChat(
    String token,
    String text, {
    String? conversationId,
    String mode = 'chat',
  }) async* {
    HttpClient? client;
    try {
      client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 15);

      final request = await client.postUrl(Uri.parse('$baseUrl$chatStreamPath'));
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json; charset=utf-8');
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
      if (token.isNotEmpty) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }
      final body = <String, dynamic>{
        'text': text,
        'mode': mode,
      };
      if (conversationId != null) body['conversation_id'] = conversationId;
      request.add(utf8.encode(jsonEncode(body)));

      final response = await request.close();

      if (response.statusCode != HttpStatus.ok) {
        yield SSEEvent(type: 'error', text: _friendlyStatus(response.statusCode));
        return;
      }

      String? eventType;
      await for (final rawLine
          in response.transform(utf8.decoder).transform(const LineSplitter())) {
        final line = rawLine.trim();
        if (line.isEmpty) continue;
        if (line.startsWith(':')) continue;

        if (line.startsWith('event:')) {
          eventType = line.substring('event:'.length).trim();
          continue;
        }

        if (!line.startsWith('data:')) continue;

        final payload = line.substring('data:'.length).trim();
        if (payload == '[DONE]') {
          yield SSEEvent(type: 'done');
          return;
        }

        Map<String, dynamic>? jsonData;
        try {
          final decoded = jsonDecode(payload);
          if (decoded is Map<String, dynamic>) jsonData = decoded;
        } on FormatException {
          // ignore non-JSON data lines
        }

        final type = _normalizeType(eventType ?? 'chunk');

        if (type == 'done') {
          yield SSEEvent(type: 'done', data: jsonData);
          return;
        }

        if (type == 'error') {
          final detail = (jsonData?['message'] ?? jsonData?['detail'])?.toString();
          yield SSEEvent(
            type: 'error',
            text: detail == null || detail.trim().isEmpty
                ? 'Não foi possível concluir a solicitação. Tente novamente.'
                : detail,
          );
          return;
        }

        if (type == 'thinking') {
          yield SSEEvent(
            type: 'thinking',
            text: (jsonData?['title'] ?? jsonData?['text'])?.toString(),
            data: jsonData,
          );
        } else if (type == 'pantry_updated' ||
            type == 'pantry_done' ||
            type == 'recipe_ready') {
          yield SSEEvent(type: type, data: jsonData);
        } else {
          yield SSEEvent(
            type: 'chunk',
            text: (jsonData?['text'] ?? jsonData?['content'] ?? jsonData?['delta'])?.toString(),
            data: jsonData,
          );
        }

        eventType = null;
      }
    } on SocketException {
      yield const SSEEvent(
        type: 'error',
        text: 'Não foi possível conectar ao servidor. Verifique sua internet e tente novamente.',
      );
    } on HttpException {
      yield const SSEEvent(
        type: 'error',
        text: 'O servidor demorou para responder. Verifique sua conexão e tente novamente.',
      );
    } catch (_) {
      yield const SSEEvent(type: 'error', text: 'Erro inesperado. Tente novamente.');
    } finally {
      client?.close(force: true);
    }
  }

  String _friendlyStatus(int code) {
    if (code == 401 || code == 403) return 'Sessão expirada. Entre novamente.';
    if (code == 429) return 'Você atingiu o limite de mensagens por agora. Aguarde e tente novamente.';
    if (code >= 500) return 'Servidor indisponível no momento. Tente novamente em instantes.';
    if (code == 404) return 'Serviço não encontrado. Tente novamente.';
    return 'Não foi possível concluir a solicitação. Tente novamente.';
  }

  String _normalizeType(String type) {
    switch (type.toLowerCase()) {
      case 'chunk':
      case 'thinking':
      case 'done':
      case 'error':
      case 'pantry_updated':
      case 'pantry_done':
      case 'recipe_ready':
        return type.toLowerCase();
      case 'end':
      case 'finish':
        return 'done';
      default:
        return 'chunk';
    }
  }
}
