import 'package:splitpal/core/network/dio_client.dart';
import '../../../../core/error/exceptions.dart';

abstract class GroupRemoteDataSource {
  Future<List<dynamic>> getUserGroups();
  Future<List<dynamic>> getPendingInvites();
  Future<Map<String, dynamic>> createGroup(String name, String currency);
  Future<Map<String, dynamic>> getGroupDetails(String groupId);
  Future<List<dynamic>> getGroupMembers(String groupId);
  Future<Map<String, dynamic>> createInvite(String groupId, String email);
  Future<Map<String, dynamic>> acceptInvite(String token);
  Future<Map<String, dynamic>> getGroupBalance(String groupId);
  Future<Map<String, dynamic>> transferOwnership(String groupId, String newOwnerId);
  Future<Map<String, dynamic>> updateMemberRole(String groupId, String memberId, String role);
}

class GroupRemoteDataSourceImpl implements GroupRemoteDataSource {
  final DioClient dioClient;

  GroupRemoteDataSourceImpl(this.dioClient);

  @override
  Future<List<dynamic>> getUserGroups() async {
    try {
      final response = await dioClient.get('/groups');
      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map && data.containsKey('data')) {
           return data['data'];
        } else if (data is List) {
           return data;
        }
        return [];
      } else {
        throw ServerException(message: 'Server error');
      }
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<List<dynamic>> getPendingInvites() async {
    try {
      final response = await dioClient.get('/groups/invites/pending'); 
      if (response.statusCode == 200) {
         final data = response.data;
        if (data is Map && data.containsKey('data')) {
           return data['data'];
        } else if (data is List) {
           return data;
        }
        return [];
      } else {
        throw ServerException(message: 'Server error');
      }
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<Map<String, dynamic>> createGroup(String name, String currency) async {
    try {
      final response = await dioClient.post(
        '/groups',
        data: {'name': name, 'baseCurrency': currency},
      );
      if (response.statusCode == 201 || response.statusCode == 200) {
        if (response.data is Map && response.data.containsKey('data')) {
           return response.data['data'];
        }
        return response.data; // Fallback
      } else {
        throw ServerException(message: response.data['error']?['message'] ?? 'Failed to create group');
      }
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<Map<String, dynamic>> getGroupDetails(String groupId) async {
    try {
      final response = await dioClient.get('/groups/$groupId');
      if (response.statusCode == 200) {
        return response.data['data'];
      } else {
        throw ServerException(message: 'Failed to get group details');
      }
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<List<dynamic>> getGroupMembers(String groupId) async {
    try {
      final response = await dioClient.get('/groups/$groupId/members');
      if (response.statusCode == 200) {
        return response.data['data'];
      } else {
        throw ServerException(message: 'Failed to get group members');
      }
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<Map<String, dynamic>> createInvite(String groupId, String email) async {
    try {
      final response = await dioClient.post(
        '/groups/$groupId/invites',
        data: {'emailInvite': email, 'role': 'USER'}, // Default role - must match backend enum: OWNER, ADMIN, USER
      );
      if (response.statusCode == 201) {
        return response.data['data'];
      } else {
        throw ServerException(message: 'Failed to send invite');
      }
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<Map<String, dynamic>> acceptInvite(String token) async {
    try {
      final response = await dioClient.post(
        '/groups/invites/accept',
        data: {'token': token},
      );
      if (response.statusCode == 200) {
        return response.data['data'];
      } else {
        throw ServerException(message: 'Failed to accept invite');
      }
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<Map<String, dynamic>> getGroupBalance(String groupId) async {
    try {
      final response = await dioClient.get('/groups/$groupId/balance');
      if (response.statusCode == 200) {
        return response.data['data'];
      } else {
        throw ServerException(message: 'Failed to get group balance');
      }
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<Map<String, dynamic>> transferOwnership(String groupId, String newOwnerId) async {
    try {
      final response = await dioClient.post(
        '/groups/$groupId/transfer-ownership',
        data: {'newOwnerId': newOwnerId},
      );
      if (response.statusCode == 200) {
        return response.data['data'];
      } else {
        throw ServerException(message: 'Failed to transfer ownership');
      }
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<Map<String, dynamic>> updateMemberRole(String groupId, String memberId, String role) async {
    try {
      final response = await dioClient.patch(
        '/groups/$groupId/members/$memberId/role',
        data: {'role': role},
      );
      if (response.statusCode == 200) {
        return response.data['data'];
      } else {
        throw ServerException(message: 'Failed to update member role');
      }
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }
}
