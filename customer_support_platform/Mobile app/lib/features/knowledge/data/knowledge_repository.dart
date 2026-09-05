import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../dashboard/presentation/knowledge_screen.dart';

class KnowledgeRepository {
  final ApiClient apiClient;

  KnowledgeRepository({required this.apiClient});

  Future<List<KnowledgeArticle>> getDocuments() async {
    try {
      final response = await apiClient.dio.get('/knowledge/documents');
      final list = response.data as List;
      return list
          .map((item) => KnowledgeArticle.fromJson(
                Map<String, dynamic>.from(item as Map),
              ))
          .toList();
    } on DioException catch (e) {
      throw Exception('Failed to load knowledge documents: ${e.message}');
    }
  }

  Future<KnowledgeArticle> getDocument(String id) async {
    try {
      final response = await apiClient.dio.get('/knowledge/documents/$id');
      return KnowledgeArticle.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
    } on DioException catch (e) {
      throw Exception('Failed to load knowledge document: ${e.message}');
    }
  }
}
