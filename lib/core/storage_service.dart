import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;

class StorageService {
  final SupabaseClient _supabase;

  StorageService(this._supabase);

  Future<String?> uploadImage({
    required File file,
    required String bucket,
    required String pathPrefix,
  }) async {
    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}${path.extension(file.path)}';
      final filePath = '$pathPrefix/$fileName';

      await _supabase.storage.from(bucket).upload(
        filePath,
        file,
        fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
      );

      return _supabase.storage.from(bucket).getPublicUrl(filePath);
    } catch (e) {
      throw Exception('Error uploading image: $e');
    }
  }

  Future<void> deleteImage(String bucket, String url) async {
    try {
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;
      // Supabase public URL format is usually: 
      // .../storage/v1/object/public/bucketName/path/to/file.ext
      final objectPath = pathSegments.sublist(pathSegments.indexOf(bucket) + 1).join('/');
      
      await _supabase.storage.from(bucket).remove([objectPath]);
    } catch (e) {
       // Ignore or log error
    }
  }
}
