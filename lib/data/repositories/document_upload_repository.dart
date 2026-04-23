import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class UploadedDocumentResult {
  final String id;
  final String fileName;
  final String mimeType;
  final String status;
  final String storageUrl;

  const UploadedDocumentResult({
    required this.id,
    required this.fileName,
    required this.mimeType,
    required this.status,
    required this.storageUrl,
  });

  factory UploadedDocumentResult.fromJson(Map<String, dynamic> json) {
    final document = json['document'] as Map<String, dynamic>? ?? const {};
    return UploadedDocumentResult(
      id: document['_id']?.toString() ?? '',
      fileName: document['fileName']?.toString() ?? '',
      mimeType: document['mimeType']?.toString() ?? '',
      status: document['status']?.toString() ?? '',
      storageUrl: document['storageUrl']?.toString() ?? '',
    );
  }
}

class DocumentUploadRepository {
  static const String _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000',
  );

  final http.Client _client;

  DocumentUploadRepository({http.Client? client})
      : _client = client ?? http.Client();

  Future<UploadedDocumentResult> uploadDocument({
    required String businessId,
    required PlatformFile file,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/documents/upload');
    final request = http.MultipartRequest('POST', uri)
      ..fields['businessId'] = businessId;

    final bytes = await _readFileBytes(file);
    final multipartFile = http.MultipartFile.fromBytes(
      'file',
      bytes,
      filename: file.name,
      contentType: _contentTypeForName(file.name),
    );
    request.files.add(multipartFile);

    final streamed = await _client.send(request).timeout(
          const Duration(seconds: 60),
        );
    final response = await http.Response.fromStream(streamed);

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400 || body['success'] != true) {
      throw Exception(body['error'] ?? 'Upload failed');
    }

    return UploadedDocumentResult.fromJson(
      body['data'] as Map<String, dynamic>,
    );
  }

  Future<Uint8List> _readFileBytes(PlatformFile file) async {
    if (file.bytes != null) return file.bytes!;
    if (file.readStream != null) {
      return http.ByteStream(file.readStream!).toBytes();
    }
    throw Exception('Selected file could not be read');
  }

  MediaType _contentTypeForName(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.pdf')) {
      return MediaType('application', 'pdf');
    }
    if (lower.endsWith('.png')) {
      return MediaType('image', 'png');
    }
    return MediaType('image', 'jpeg');
  }
}
