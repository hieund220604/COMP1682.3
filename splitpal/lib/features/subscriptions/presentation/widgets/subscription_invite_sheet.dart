import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:splitpal/features/auth/auth_provider.dart';
import 'package:splitpal/features/subscriptions/subscription_provider.dart';
import 'package:splitpal/models/subscription.dart';

class SubscriptionInviteSheet extends StatefulWidget {
  final Subscription subscription;
  
  const SubscriptionInviteSheet({super.key, required this.subscription});

  @override
  State<SubscriptionInviteSheet> createState() => _SubscriptionInviteSheetState();
}

class _SubscriptionInviteSheetState extends State<SubscriptionInviteSheet> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.length < 3) return;

    setState(() => _isSearching = true);
    
    final authProvider = context.read<AuthProvider>();
    final results = await authProvider.searchUsers(query);
    
    if (!mounted) return;

    // Filter out users already in the subscription
    final existingIds = <String>{
      ...widget.subscription.members.where((m) => m.isActive).map((m) => m.userId),
      ...widget.subscription.pendingInvitations.where((i) => i.isPending).map((i) => i.inviteeId),
    };

    setState(() {
      _searchResults = results.where((u) => !existingIds.contains(u['id'])).toList();
      _isSearching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<SubscriptionProvider>();
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 24, 16, 16 + viewInsets),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Invite Member',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                )
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by email...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: _performSearch,
                ),
              ),
              onSubmitted: (_) => _performSearch(),
              textInputAction: TextInputAction.search,
              autofocus: true,
            ),
            const SizedBox(height: 16),
            if (_isSearching)
              const Center(child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              ))
            else if (_searchResults.isEmpty && _searchController.text.length >= 3)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: Text('No users found.')),
              )
            else if (_searchResults.isNotEmpty)
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _searchResults.length,
                  itemBuilder: (ctx, idx) {
                    final u = _searchResults[idx];
                    final userId = u['id'] as String;
                    final email = u['email'] as String;
                    final name = u['displayName'] as String? ?? email;
                    final avatar = name.isNotEmpty ? name[0].toUpperCase() : '?';

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(child: Text(avatar)),
                      title: Text(name),
                      subtitle: name != email ? Text(email, style: const TextStyle(fontSize: 12)) : null,
                      trailing: const Icon(Icons.send, size: 18),
                      onTap: () async {
                        Navigator.pop(context);
                        final ok = await provider.invite(
                          subscriptionId: widget.subscription.id,
                          inviteeId: userId,
                        );
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(ok
                              ? 'Invitation sent to $name'
                              : (provider.actionError ?? 'Failed to invite')),
                          backgroundColor: ok ? Colors.green : Theme.of(context).colorScheme.error,
                        ));
                        if (!ok) provider.clearActionError();
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
