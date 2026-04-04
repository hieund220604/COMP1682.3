import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/group_provider.dart';
import 'group_detail_page.dart';
import 'create_group_page.dart';

class GroupsPage extends StatefulWidget {
  const GroupsPage({super.key});

  @override
  State<GroupsPage> createState() => _GroupsPageState();
}

class _GroupsPageState extends State<GroupsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GroupProvider>().fetchGroupsAndInvites();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text(
          'Your Groups',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateGroupPage()),
              );
            },
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: Consumer<GroupProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.groups.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.group_off, size: 64, color: theme.colorScheme.outlineVariant),
                  const SizedBox(height: 16),
                  Text(
                    'No groups found',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Tạo nhóm mới hoặc nhập mã mời để bắt đầu.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FilledButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const CreateGroupPage()),
                          );
                        },
                        child: const Text('Tạo nhóm'),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton(
                        onPressed: () async {
                          final token = await _promptInviteToken(context);
                          if (token?.isNotEmpty ?? false) {
                            final success = await context.read<GroupProvider>().joinGroup(token!.trim());
                            if (!context.mounted) return;
                            final snackBar = SnackBar(
                              content: Text(
                                success ? 'Joined group successfully' : 'Failed to join group',
                              ),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(snackBar);
                          }
                        },
                        child: const Text('Nhập mã mời'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: provider.groups.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final group = provider.groups[index];
              final name = group['name'] ?? 'Group';
              final membersCount = (group['members'] as List?)?.length ?? 0;
              final groupId = group['_id'] ?? group['id'];

              return Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.apartment, color: theme.colorScheme.primary),
                  ),
                  title: Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  subtitle: Text('$membersCount members'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                  onTap: () {
                     Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GroupDetailPage(
                          groupId: groupId,
                          groupName: name,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<String?> _promptInviteToken(BuildContext context) async {
    final controller = TextEditingController();
    final token = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nhập mã mời'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Invite token',
            prefixIcon: Icon(Icons.key),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Tham gia'),
          ),
        ],
      ),
    );
    controller.dispose();
    return token;
  }
}
