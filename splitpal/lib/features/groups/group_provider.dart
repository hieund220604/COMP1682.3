import 'package:flutter/foundation.dart';

import '../../core/network/dio_client.dart';

/// Fat Provider — calls DioClient directly for all group operations.
class GroupProvider extends ChangeNotifier {
  final DioClient _dio;

  GroupProvider({required DioClient dio}) : _dio = dio;

  // ─── State ──────────────────────────────────────────────
  List<dynamic> groups = [];
  List<dynamic> invites = [];
  bool isLoading = false;
  String? error;

  // Current group detail state
  Map<String, dynamic>? currentGroup;
  List<dynamic> currentGroupMembers = [];
  Map<String, dynamic>? currentGroupBalance;
  String? currentUserRole; // OWNER, ADMIN, USER

  // Permission helpers
  bool get isOwnerOrAdmin =>
      currentUserRole == 'OWNER' || currentUserRole == 'ADMIN';
  bool get isOwner => currentUserRole == 'OWNER';

  // ─── Groups + Invites ───────────────────────────────────
  Future<void> fetchGroupsAndInvites() async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final groupsResp = await _dio.get('/groups');
      final data = groupsResp.data;
      if (data is Map && data.containsKey('data')) {
        groups = data['data'];
      } else if (data is List) {
        groups = data;
      } else {
        groups = [];
      }
    } catch (e) {
      error = e.toString();
    }

    try {
      final invitesResp = await _dio.get('/groups/invites/pending');
      final data = invitesResp.data;
      if (data is Map && data.containsKey('data')) {
        invites = data['data'];
      } else if (data is List) {
        invites = data;
      } else {
        invites = [];
      }
    } catch (_) {
      // Silently fail for invites
    }

    isLoading = false;
    notifyListeners();
  }

  // ─── Create Group ───────────────────────────────────────
  Future<bool> createGroup(String name, String currency) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      await _dio.post('/groups', data: {
        'name': name,
        'baseCurrency': currency,
      });
      await fetchGroupsAndInvites();
      return true;
    } catch (e) {
      error = e.toString();
      isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ─── Group Details ──────────────────────────────────────
  Future<void> fetchGroupDetailsData(String groupId,
      {String? currentUserId}) async {
    isLoading = true;
    error = null;
    currentGroup = null;
    currentGroupMembers = [];
    currentGroupBalance = null;
    currentUserRole = null;
    notifyListeners();

    // Fetch details
    try {
      final resp = await _dio.get('/groups/$groupId');
      currentGroup = resp.data['data'];
    } catch (e) {
      error = e.toString();
    }

    // Fetch members
    try {
      final resp = await _dio.get('/groups/$groupId/members');
      currentGroupMembers = resp.data['data'];

      // Find current user's role
      if (currentUserId != null) {
        for (final m in currentGroupMembers) {
          if (m is! Map<String, dynamic>) continue;
          final userMap = m['user'];
          final memberUserId = (m['userId'] ??
                  (userMap is Map<String, dynamic> ? userMap['id'] : null) ??
                  (userMap is Map<String, dynamic> ? userMap['_id'] : null))
              ?.toString();

          if (memberUserId != null && memberUserId == currentUserId) {
            currentUserRole = m['role']?.toString().toUpperCase();
            break;
          }
        }
      }
    } catch (e) {
      error = e.toString();
    }

    // Fetch balance
    try {
      final resp = await _dio.get('/groups/$groupId/balance');
      final data = resp.data['data'];
      if (data['members'] is List && currentUserId != null) {
        final members = data['members'] as List;
        final userBalance = members.firstWhere(
          (m) => m['userId'] == currentUserId,
          orElse: () => null,
        );
        if (userBalance != null) {
          currentGroupBalance = {
            'totalSpent': (userBalance['totalLent'] ?? 0).toDouble(),
            'netBalance': (userBalance['netBalance'] ?? 0).toDouble(),
          };
        }
      }
    } catch (_) {
      // Non-critical
    }

    isLoading = false;
    notifyListeners();
  }

  // ─── Invite Member ──────────────────────────────────────
  Future<bool> inviteMember(String groupId, String email) async {
    isLoading = true;
    notifyListeners();

    try {
      await _dio.post('/groups/$groupId/invites', data: {
        'emailInvite': email,
        'role': 'USER',
      });
      isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      error = e.toString();
      isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ─── Accept Invite ──────────────────────────────────────
  Future<bool> joinGroup(String token) async {
    isLoading = true;
    notifyListeners();

    try {
      await _dio.post('/groups/invites/accept', data: {'token': token});
      await fetchGroupsAndInvites();
      return true;
    } catch (e) {
      error = e.toString();
      isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ─── Join by Code ───────────────────────────────────────
  Future<bool> joinGroupByCode(String code) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      await _dio.post('/groups/join-by-code', data: {'code': code});
      await fetchGroupsAndInvites();
      return true;
    } catch (e) {
      error = e.toString();
      isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ─── Transfer Ownership ─────────────────────────────────
  Future<void> transferOwnership(String groupId, String newOwnerId) async {
    try {
      await _dio.post('/groups/$groupId/transfer-ownership', data: {
        'newOwnerId': newOwnerId,
      });
      await fetchGroupDetailsData(groupId);
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  // ─── Update Member Role ─────────────────────────────────
  Future<void> updateMemberRole(
      String groupId, String memberId, String role) async {
    try {
      await _dio.patch('/groups/$groupId/members/$memberId/role', data: {
        'role': role,
      });
      await fetchGroupDetailsData(groupId);
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  // ─── Leave Group ────────────────────────────────────────
  Future<bool> leaveGroup(String groupId) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      await _dio.post('/groups/$groupId/leave');
      // Remove from local list immediately
      groups = groups.where((g) {
        final id = (g['_id'] ?? g['id'])?.toString();
        return id != groupId;
      }).toList();
      isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      error = e.toString();
      isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
