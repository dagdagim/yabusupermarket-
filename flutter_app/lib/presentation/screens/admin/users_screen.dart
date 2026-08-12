import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../providers/app_providers.dart';
import '../../widgets/common_widgets.dart';

class UsersScreen extends ConsumerStatefulWidget {
  const UsersScreen({super.key});

  @override
  ConsumerState<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends ConsumerState<UsersScreen> {
  final List<UserModel> _users = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final data = await ref.read(apiServiceProvider).getUsers();
      setState(() {
        _users
          ..clear()
          ..addAll((data['data'] as List<dynamic>? ?? [])
              .map((u) => UserModel.fromJson(u)));
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load users: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _editUser(UserModel user) async {
    final nameController = TextEditingController(text: user.name);
    final passwordController = TextEditingController();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(user.isAdmin ? 'Edit Admin Password' : 'Edit Shopkeeper'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              enabled: user.isShopkeeper,
              decoration: const InputDecoration(
                labelText: 'Username',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'New Password',
                hintText: 'Leave blank to keep current',
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final password = passwordController.text.trim();
              if (password.isNotEmpty && password.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Password must be at least 6 characters'),
                    backgroundColor: AppColors.error,
                  ),
                );
                return;
              }

              setState(() => _isSaving = true);
              try {
                final payload = <String, dynamic>{};
                if (user.isShopkeeper) {
                  payload['name'] = nameController.text.trim();
                }
                if (password.isNotEmpty) {
                  payload['password'] = password;
                }

                if (payload.isEmpty) {
                  Navigator.pop(ctx, false);
                  return;
                }

                final data =
                    await ref.read(apiServiceProvider).updateUser(user.id, payload);
                if (data['success'] == true && ctx.mounted) {
                  Navigator.pop(ctx, true);
                }
              } on DioException catch (e) {
                final msg = (e.response?.data as Map?)?['message']?.toString();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(msg ?? 'Failed to update user'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to update user: $e'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              } finally {
                if (mounted) setState(() => _isSaving = false);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    nameController.dispose();
    passwordController.dispose();

    if (saved == true) {
      await _loadUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User updated'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _isSaving,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Manage Users'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadUsers,
            ),
          ],
        ),
        body: _isLoading
            ? const Padding(
                padding: EdgeInsets.all(16),
                child: ShimmerList(itemCount: 6),
              )
            : _users.isEmpty
                ? EmptyStateWidget(
                    message: 'No users found',
                    icon: Icons.people_outline,
                    actionLabel: 'Refresh',
                    onAction: _loadUsers,
                  )
                : RefreshIndicator(
                    onRefresh: _loadUsers,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _users.length,
                      itemBuilder: (_, i) {
                        final user = _users[i];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: user.isAdmin
                                  ? AppColors.primary
                                  : AppColors.accent,
                              child: Text(
                                user.name.isNotEmpty
                                    ? user.name.substring(0, 1).toUpperCase()
                                    : '?',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            title: Text(
                              user.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Sora',
                              ),
                            ),
                            subtitle: Text(
                              user.isAdmin
                                  ? '${user.email} • Admin'
                                  : '${user.email} • ${user.shop?.name ?? 'No shop'}',
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () => _editUser(user),
                              tooltip: 'Edit user',
                            ),
                          ),
                        );
                      },
                    ),
                  ),
      ),
    );
  }
}
