import 'package:flutter/foundation.dart';
import '../../domain/usecases/get_user_groups.dart';
import '../../domain/usecases/get_pending_invites.dart';
import '../../domain/usecases/create_group.dart';
import '../../domain/usecases/get_group_details.dart';
import '../../domain/usecases/get_group_members.dart';
import '../../domain/usecases/create_invite.dart';
import '../../domain/usecases/accept_invite.dart';
import '../../domain/usecases/get_group_balance.dart';
import '../../domain/repositories/group_repository.dart';

class GroupProvider extends ChangeNotifier {
  final GetUserGroups getUserGroups;
  final GetPendingInvites getPendingInvites;
  final CreateGroup createGroupUseCase;
  final GetGroupDetails getGroupDetails;
  final GetGroupMembers getGroupMembers;
  final CreateInvite createInvite;
  final AcceptInvite acceptInvite;
  final GetGroupBalance getGroupBalance;
  final GroupRepository groupRepository;

  List<dynamic> _groups = [];
  List<dynamic> _invites = [];
  bool _isLoading = false;
  String? _error;

  // Specific Group Details
  Map<String, dynamic>? _currentGroup;
  List<dynamic> _currentGroupMembers = [];
  Map<String, dynamic>? _currentGroupBalance;
  String? _currentUserRole; // OWNER, ADMIN, USER

  GroupProvider({
    required this.getUserGroups,
    required this.getPendingInvites,
    required this.createGroupUseCase,
    required this.getGroupDetails,
    required this.getGroupMembers,
    required this.createInvite,
    required this.acceptInvite,
    required this.getGroupBalance,
    required this.groupRepository,
  });

  List<dynamic> get groups => _groups;
  List<dynamic> get invites => _invites;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Map<String, dynamic>? get currentGroup => _currentGroup;
  List<dynamic> get currentGroupMembers => _currentGroupMembers;
  Map<String, dynamic>? get currentGroupBalance => _currentGroupBalance;
  String? get currentUserRole => _currentUserRole;

  // Helper methods to check permissions
  bool get isOwnerOrAdmin => _currentUserRole == 'OWNER' || _currentUserRole == 'ADMIN';
  bool get isOwner => _currentUserRole == 'OWNER';

  Future<void> fetchGroupsAndInvites() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final groupsResult = await getUserGroups();
    final invitesResult = await getPendingInvites();

    groupsResult.fold(
      (failure) => _error = failure.message,
      (data) => _groups = data,
    );

    invitesResult.fold(
      (failure) {}, // Silently fail for invites
      (data) => _invites = data,
    );

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> createGroup(String name, String currency) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await createGroupUseCase(name, currency);
    bool success = false;

    result.fold(
      (failure) {
        _error = failure.message;
        success = false;
      },
      (data) {
        // Refresh groups list
        fetchGroupsAndInvites();
        success = true;
      },
    );

    _isLoading = false;
    notifyListeners();
    return success;
  }

  Future<void> fetchGroupDetailsData(String groupId, {String? currentUserId}) async {
    _isLoading = true;
    _error = null;
    _currentGroup = null;
    _currentGroupMembers = [];
    _currentGroupBalance = null;
    _currentUserRole = null;
    notifyListeners();

    final detailsResult = await getGroupDetails(groupId);
    final membersResult = await getGroupMembers(groupId);
    final balanceResult = await getGroupBalance(groupId);

    detailsResult.fold(
      (failure) => _error = failure.message,
      (data) => _currentGroup = data,
    );

    membersResult.fold(
      (failure) => _error = failure.message,
      (data) {
        _currentGroupMembers = data;
        // Find current user's role
        if (currentUserId != null) {
          Map<String, dynamic>? currentUserMember;

          for (final m in (data as List)) {
            if (m is! Map<String, dynamic>) continue;

            final userMap = m['user'];
            final memberUserId = (m['userId'] ??
                    (userMap is Map<String, dynamic> ? userMap['id'] : null) ??
                    (userMap is Map<String, dynamic> ? userMap['_id'] : null))
                ?.toString();

            if (memberUserId != null && memberUserId == currentUserId) {
              currentUserMember = m;
              break;
            }
          }

          _currentUserRole =
              currentUserMember?['role']?.toString().toUpperCase();
        }
      },
    );

    balanceResult.fold(
      (failure) {},
      (data) {
        // Balance API returns: {groupId, members: [{userId, totalOwed, totalLent, netBalance}]}
        // Find current user's balance in members array
        if (data['members'] is List && currentUserId != null) {
          final members = data['members'] as List;
          final userBalance = members.firstWhere(
            (m) => m['userId'] == currentUserId,
            orElse: () => null,
          );

          if (userBalance != null) {
            _currentGroupBalance = {
              'totalSpent': (userBalance['totalLent'] ?? 0).toDouble(),
              'netBalance': (userBalance['netBalance'] ?? 0).toDouble(),
            };
          }
        }
      },
    );

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> inviteMember(String groupId, String email) async {
    _isLoading = true;
    notifyListeners();

    final result = await createInvite(groupId, email);
    bool success = false;

    result.fold(
      (failure) {
        _error = failure.message;
        success = false;
      },
      (data) {
        success = true;
      },
    );

    _isLoading = false;
    notifyListeners();
    return success;
  }

  Future<bool> joinGroup(String token) async {
    _isLoading = true;
    notifyListeners();

    final result = await acceptInvite(token);
    bool success = false;

    result.fold(
      (failure) {
        _error = failure.message;
        success = false;
      },
      (data) {
        fetchGroupsAndInvites();
        success = true;
      },
    );

    _isLoading = false;
    notifyListeners();
    return success;
  }

  Future<void> transferOwnership(String groupId, String newOwnerId) async {
    final result = await groupRepository.transferOwnership(groupId, newOwnerId);
    
    result.fold(
      (failure) {
        throw Exception(failure.message);
      },
      (data) {
        // Refresh group details to update roles
        fetchGroupDetailsData(groupId);
      },
    );
  }

  Future<void> updateMemberRole(String groupId, String memberId, String role) async {
    final result = await groupRepository.updateMemberRole(groupId, memberId, role);
    
    result.fold(
      (failure) {
        throw Exception(failure.message);
      },
      (data) {
        // Refresh group details to update roles
        fetchGroupDetailsData(groupId);
      },
    );
  }
}
