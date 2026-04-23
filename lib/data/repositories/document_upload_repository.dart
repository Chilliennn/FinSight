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

class UploadedDocumentStatusResult {
  final String id;
  final String status;
  final String? parsingNotes;
  final String? stage;

  const UploadedDocumentStatusResult({
    required this.id,
    required this.status,
    required this.parsingNotes,
    required this.stage,
  });

  factory UploadedDocumentStatusResult.fromJson(Map<String, dynamic> json) {
    String? stage;
    final parsingNotes = json['parsingNotes']?.toString();
    if (parsingNotes != null && parsingNotes.trim().startsWith('{')) {
      try {
        final decoded = jsonDecode(parsingNotes) as Map<String, dynamic>;
        stage = decoded['stage']?.toString();
      } catch (_) {
        stage = null;
      }
    }

    return UploadedDocumentStatusResult(
      id: json['_id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'uploaded',
      parsingNotes: parsingNotes,
      stage: stage,
    );
  }
}

class UploadedDocumentListItem {
  final String? documentId;
  final String key;
  final String fileName;
  final String? mimeType;
  final String status;
  final int size;
  final DateTime? lastModified;
  final String storageUrl;
  final String documentType;
  final bool? ocrRequired;
  final int? totalPages;
  final String? parsingNotes;
  final String? extractionMethod;
  final String? documentAiProcessor;
  final String? chunkPreview;

  const UploadedDocumentListItem({
    required this.documentId,
    required this.key,
    required this.fileName,
    required this.mimeType,
    required this.status,
    required this.size,
    required this.lastModified,
    required this.storageUrl,
    required this.documentType,
    required this.ocrRequired,
    required this.totalPages,
    required this.parsingNotes,
    required this.extractionMethod,
    required this.documentAiProcessor,
    required this.chunkPreview,
  });

  factory UploadedDocumentListItem.fromJson(Map<String, dynamic> json) {
    final parsingNotes = json['parsingNotes']?.toString();
    String? extractionMethod;
    String? documentAiProcessor;

    if (parsingNotes != null && parsingNotes.trim().startsWith('{')) {
      try {
        final decoded = jsonDecode(parsingNotes) as Map<String, dynamic>;
        extractionMethod = decoded['extractionMethod']?.toString();
        documentAiProcessor = decoded['documentAiProcessor']?.toString();
      } catch (_) {
        extractionMethod = null;
        documentAiProcessor = null;
      }
    }

    return UploadedDocumentListItem(
      documentId: json['documentId']?.toString(),
      key: json['key']?.toString() ?? '',
      fileName: json['fileName']?.toString() ?? '',
      mimeType: json['mimeType']?.toString(),
      status: json['status']?.toString() ?? 'uploaded',
      size: (json['size'] as num?)?.toInt() ?? 0,
      lastModified: json['lastModified'] != null
          ? DateTime.tryParse(json['lastModified'].toString())
          : null,
      storageUrl: json['storageUrl']?.toString() ?? '',
      documentType: json['documentType']?.toString() ?? 'unknown',
      ocrRequired: json['ocrRequired'] as bool?,
      totalPages: (json['totalPages'] as num?)?.toInt(),
      parsingNotes: parsingNotes,
      extractionMethod: extractionMethod,
      documentAiProcessor: documentAiProcessor,
      chunkPreview: json['chunkPreview']?.toString(),
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

  Map<String, dynamic> _decodeEnvelope(http.Response response) {
    final trimmedBody = response.body.trimLeft();
    final contentType = response.headers['content-type'] ?? '';
    final looksLikeJson =
        contentType.contains('application/json') ||
        trimmedBody.startsWith('{') ||
        trimmedBody.startsWith('[');

    if (!looksLikeJson) {
      final snippet = trimmedBody.length > 120
          ? '${trimmedBody.substring(0, 120)}...'
          : trimmedBody;
      throw Exception(
        'API returned non-JSON response (${response.statusCode}). '
        'Make sure the Node backend is running and restarted on $_baseUrl. '
        'Received: $snippet',
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400 || body['success'] != true) {
      throw Exception(body['error'] ?? 'Request failed');
    }

    return body;
  }

  Future<List<UploadedDocumentListItem>> fetchDocuments(String businessId) async {
    final uri = Uri.parse('$_baseUrl/api/documents?businessId=$businessId');
    final response = await _client
        .get(uri)
        .timeout(const Duration(seconds: 30));

    final body = _decodeEnvelope(response);
    final data = body['data'] as Map<String, dynamic>? ?? const {};
    final items = data['items'] as List<dynamic>? ?? const [];
    return items
        .map((item) => UploadedDocumentListItem.fromJson(
              item as Map<String, dynamic>,
            ))
        .toList();
  }

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

    final body = _decodeEnvelope(response);
    return UploadedDocumentResult.fromJson(
      body['data'] as Map<String, dynamic>,
    );
  }

  Future<UploadedDocumentStatusResult> fetchDocumentStatus(String documentId) async {
    final uri = Uri.parse('$_baseUrl/api/documents/$documentId');
    final response = await _client
        .get(uri)
        .timeout(const Duration(seconds: 30));

    final body = _decodeEnvelope(response);
    return UploadedDocumentStatusResult.fromJson(
      body['data'] as Map<String, dynamic>,
    );
  }

  Future<void> deleteDocument({
    required String businessId,
    String? documentId,
    String? key,
  }) async {
    if ((documentId == null || documentId.isEmpty) &&
        (key == null || key.isEmpty)) {
      throw Exception('documentId or key is required to delete a file');
    }

    final queryParameters = <String, String>{
      'businessId': businessId,
      if (documentId != null && documentId.isNotEmpty) 'documentId': documentId,
      if (key != null && key.isNotEmpty) 'key': key,
    };

    final uri = Uri.parse('$_baseUrl/api/documents')
        .replace(queryParameters: queryParameters);
    final response = await _client
        .delete(uri)
        .timeout(const Duration(seconds: 30));

    _decodeEnvelope(response);
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
