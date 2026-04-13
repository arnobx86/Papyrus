import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'activity_service.dart';
import '../models/shop.dart';

class ShopProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<Shop> _shops = [];
  Shop? _currentShop;
  bool _loading = false;

  List<Shop> get shops => _shops;
  Shop? get currentShop => _currentShop;
  bool get loading => _loading;

  Future<void> fetchShops(String? userId) async {
    if (userId == null) {
      _shops = [];
      _currentShop = null;
      notifyListeners();
      return;
    }

    _loading = true;
    notifyListeners();

    try {
      // Try to fetch from member_shops view first (includes both owned and member shops)
      final response = await _supabase.from('member_shops').select();
      _shops = (response as List).map((s) => Shop.fromJson(s)).toList();

      final prefs = await SharedPreferences.getInstance();
      final savedShopId = prefs.getString('currentShopId');
      
      if (savedShopId != null && _shops.any((s) => s.id == savedShopId)) {
        _currentShop = _shops.firstWhere((s) => s.id == savedShopId);
      } else if (_shops.length == 1) {
        _currentShop = _shops[0];
        await prefs.setString('currentShopId', _shops[0].id);
      } else {
        _currentShop = null;
      }
    } catch (e) {
      debugPrint('Error fetching shops: $e');
      // Better error handling
      if (e is PostgrestException) {
        if (e.message?.contains('relation "member_shops" does not exist') == true ||
            e.message?.contains('infinite recursion') == true) {
          debugPrint('member_shops view not available, falling back to shops table only');
          // Fallback: just fetch owned shops (simplest query)
          try {
            final response = await _supabase.from('shops').select().eq('owner_user_id', userId);
            _shops = (response as List).map((s) => Shop.fromJson(s)).toList();
          } catch (e2) {
            debugPrint('Even fallback failed: $e2');
            _shops = [];
          }
        }
      } else {
        _shops = [];
      }
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<List<Map<String, dynamic>>> fetchInvitations(String email) async {
    try {
      final response = await _supabase
          .from('shop_invitations')
          .select('*')
          .eq('invited_email_or_phone', email)
          .eq('status', 'pending');
      
      final invites = List<Map<String, dynamic>>.from(response);
      if (invites.isEmpty) return [];

      final shopIds = invites.map((i) => i['shop_id']).toSet().toList();
      final roleIds = invites.map((i) => i['role_id']).toSet().toList();

      final shopsRes = await _supabase.from('shops').select('id, name').inFilter('id', shopIds);
      final rolesRes = await _supabase.from('roles').select('id, name').inFilter('id', roleIds);

      final shopMap = {for (var s in shopsRes as List) s['id']: s['name']};
      final roleMap = {for (var r in rolesRes as List) r['id']: r['name']};

      return invites.map((i) => {
        ...i,
        'shops': {'name': shopMap[i['shop_id']]},
        'roles': {'name': roleMap[i['role_id']]}
      }).toList();
    } catch (e) {
      debugPrint('Error fetching invitations: $e');
      return [];
    }
  }

  Future<void> acceptInvitation(Map<String, dynamic> invitation, String userId) async {
    try {
      // First add user as shop member - this uses 'Users can join shops via invitation' policy
      await _supabase.from('shop_members').insert({
        'shop_id': invitation['shop_id'],
        'user_id': userId,
        'role_id': invitation['role_id'],
        'status': 'active',
        'invited_by': invitation['invited_by'],
      });

      // Then update invitation status to accepted
      // Note: This might still trigger RLS if status change is considered a violation of 'status = pending'
      await _supabase.from('shop_invitations').update({'status': 'accepted'}).eq('id', invitation['id']);
      
      await fetchShops(userId);
    } catch (e) {
      debugPrint('Error accepting invitation: $e');
      rethrow;
    }
  }

  Future<void> declineInvitation(String invitationId) async {
    try {
      await _supabase.from('shop_invitations').update({'status': 'expired'}).eq('id', invitationId);
    } catch (e) {
      debugPrint('Error declining invitation: $e');
      rethrow;
    }
  }

  Future<void> setCurrentShop(Shop? shop) async {
    _currentShop = shop;
    final prefs = await SharedPreferences.getInstance();
    if (shop != null) {
      await prefs.setString('currentShopId', shop.id);
    } else {
      await prefs.remove('currentShopId');
    }
    notifyListeners();
  }

  Future<Shop?> createShop(String name, String? phone, String? address, String userId) async {
    try {
      final data = await _supabase.from('shops').insert({
        'name': name,
        'phone': phone,
        'address': address,
        'owner_user_id': userId,
      }).select().single();

      final newShop = Shop.fromJson(data);
      _shops.add(newShop);
      await setCurrentShop(newShop);
      return newShop;
    } catch (e) {
      debugPrint('Error creating shop: $e');
      
      // Better error handling for RLS recursion errors
      if (e is PostgrestException) {
        if (e.message?.contains('infinite recursion') == true) {
          throw Exception('Shop creation failed due to a security configuration issue. Please contact support.');
        } else if (e.message?.contains('permission denied') == true) {
          throw Exception('You do not have permission to create a shop. Please check your account permissions.');
        } else if (e.code == '42501') {
          throw Exception('Access denied. You may not have the required permissions to create a shop.');
        }
      }
      
      // For other errors, provide a generic but helpful message
      throw Exception('Failed to create shop: ${e.toString()}');
    }
  }

  Future<void> saveShopSettings({
    required String name,
    required String phone,
    required String address,
    required Map<String, dynamic> metadata,
  }) async {
    if (_currentShop == null) return;

    try {
      final response = await _supabase.from('shops').update({
        'name': name,
        'phone': phone,
        'address': address,
        'metadata': metadata,
      }).eq('id', _currentShop!.id).select().single();

      _currentShop = Shop.fromJson(response);
      // Update in list
      final index = _shops.indexWhere((s) => s.id == _currentShop!.id);
      if (index != -1) _shops[index] = _currentShop!;
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error saving shop settings: $e');
      rethrow;
    }
  }

  Future<void> updateInvoiceNumber(String type, int nextNo) async {
    if (_currentShop == null) return;

    final key = '${type}_next_no';
    final metadata = Map<String, dynamic>.from(_currentShop!.metadata ?? {});
    metadata[key] = nextNo;

    try {
      final response = await _supabase.from('shops').update({
        'metadata': metadata,
      }).eq('id', _currentShop!.id).select().single();

      _currentShop = Shop.fromJson(response);
      final index = _shops.indexWhere((s) => s.id == _currentShop!.id);
      if (index != -1) _shops[index] = _currentShop!;
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating invoice number: $e');
    }
  }

  Future<void> logActivity({
    required String action,
    String? entityType,
    String? entityId,
    Map<String, dynamic>? details,
  }) async {
    if (_currentShop == null) return;
    
    final activityService = ActivityService(_supabase);
    await activityService.log(
      action: action,
      shopId: _currentShop!.id,
      entityType: entityType,
      entityId: entityId,
      details: details,
    );
  }

  Future<List<Map<String, dynamic>>> getRecentActivity({int limit = 20}) async {
    if (_currentShop == null) return [];
    
    final activityService = ActivityService(_supabase);
    return await activityService.getRecentActivity(_currentShop!.id, limit: limit);
  }
}
