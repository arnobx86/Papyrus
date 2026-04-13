import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/shop_provider.dart';
import '../../core/auth_provider.dart';
import '../../core/permissions.dart';
import 'employee_report_screen.dart';

class EmployeesScreen extends StatefulWidget {
  const EmployeesScreen({super.key});

  @override
  State<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends State<EmployeesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<dynamic> _members = [];
  List<dynamic> _roles = [];
  List<dynamic> _invitations = [];
  bool _isOwner = false;
  RealtimeChannel? _membersChannel;
  RealtimeChannel? _invitationsChannel;

  final _inviteEmailController = TextEditingController();
  String? _inviteRoleId;
  bool _isInviting = false;

  // Roles Tab State
  String? _selectedRoleId;
  Map<String, dynamic> _editingPermissions = {};
  bool _isSavingRole = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchData();
    _setupRealtime();
  }

  @override
  void dispose() {
    _membersChannel?.unsubscribe();
    _invitationsChannel?.unsubscribe();
    _tabController.dispose();
    super.dispose();
  }

  void _setupRealtime() {
    final shop = context.read<ShopProvider>().currentShop;
    if (shop == null) return;

    final supabase = Supabase.instance.client;
    
    // Subscribe to shop_members changes
    _membersChannel = supabase
        .channel('shop_members')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'shop_members',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'shop_id',
            value: shop.id,
          ),
          callback: (payload) {
            if (mounted) {
              _fetchData(); // Refresh data when members change
            }
          },
        )
        .subscribe((status, error) {
          debugPrint('Shop members subscription status: $status');
          if (error != null) debugPrint('Shop members subscription error: $error');
        });

    // Subscribe to shop_invitations changes
    _invitationsChannel = supabase
        .channel('shop_invitations')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'shop_invitations',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'shop_id',
            value: shop.id,
          ),
          callback: (payload) {
            if (mounted) {
              _fetchData(); // Refresh data when invitations change
            }
          },
        )
        .subscribe((status, error) {
          debugPrint('Shop invitations subscription status: $status');
          if (error != null) debugPrint('Shop invitations subscription error: $error');
        });
  }

  Future<void> _fetchData() async {
    final shop = context.read<ShopProvider>().currentShop;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (shop == null || userId == null) {
      debugPrint('EmployeeScreen: No shop or user ID found. Shop: $shop, UserId: $userId');
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    setState(() {
      _isLoading = true;
      _isOwner = shop.ownerUserId == userId;
    });

    final auth = context.read<AuthProvider>();
    final canManageEmployees = _isOwner || Permissions.hasPermission(auth.currentPermissions, AppPermission.manageEmployees);
    final canManageRoles = _isOwner || Permissions.hasPermission(auth.currentPermissions, AppPermission.manageRoles);

    try {
      final supabase = Supabase.instance.client;
      debugPrint('EmployeeScreen: Fetching data for shop ${shop.id}, user $userId');
      
      // Fetch Roles (Global roles)
      debugPrint('EmployeeScreen: Fetching roles from roles table...');
      final rolesRes = await supabase
          .from('roles')
          .select()
          .order('name');
      
      debugPrint('EmployeeScreen: Roles query completed, result: $rolesRes');
      final List rawRolesData = rolesRes as List;
      debugPrint('EmployeeScreen: Found ${rawRolesData.length} raw roles');

      // Merge global and shop-specific roles
      Map<String, dynamic> mergedRoles = {};
      for (var r in rawRolesData) {
        if (r['shop_id'] == null) mergedRoles[r['name']] = r;
      }
      for (var r in rawRolesData) {
        if (r['shop_id'] == shop.id) mergedRoles[r['name']] = r;
      }
      final rolesData = mergedRoles.values.toList();
      
      if (rolesData.isEmpty) {
        debugPrint('EmployeeScreen: WARNING - No roles found in database. The roles table might be empty.');
        debugPrint('EmployeeScreen: Check if the roles table has been seeded with default roles.');
      }
      
      // Sort roles in specific order
      final order = ['Owner', 'Manager', 'Sales Representative', 'Inventory Staff'];
      rolesData.sort((a, b) {
        final indexA = order.indexOf(a['name']);
        final indexB = order.indexOf(b['name']);
        if (indexA != -1 && indexB != -1) return indexA.compareTo(indexB);
        return a['name'].toString().compareTo(b['name'].toString());
      });

      // Fetch Members
      debugPrint('EmployeeScreen: Fetching members for shop ${shop.id}...');
      final membersRes = await supabase
          .from('shop_members')
          .select()
          .eq('shop_id', shop.id);
      
      debugPrint('EmployeeScreen: Members query completed, result: $membersRes');
      final members = membersRes as List;
      debugPrint('EmployeeScreen: Found ${members.length} members');

      // Fetch profiles for all user IDs (including owner)
      final userIds = members.map((m) => m['user_id'] as String?).where((id) => id != null).toSet().toList();
      // Add shop owner to the list of user IDs to fetch
      if (shop.ownerUserId.isNotEmpty && !userIds.contains(shop.ownerUserId)) {
        userIds.add(shop.ownerUserId);
      }
      
      Map<String, Map<String, dynamic>> profilesMap = {};
      
      if (userIds.isNotEmpty) {
        debugPrint('EmployeeScreen: Fetching profiles for ${userIds.length} user IDs...');
        try {
          final profilesRes = await supabase
              .from('profiles')
              .select('id, email, full_name, username')
              .inFilter('id', userIds);
          
          final profilesList = profilesRes as List;
          debugPrint('EmployeeScreen: Found ${profilesList.length} profiles');
          
          for (var profile in profilesList) {
            profilesMap[profile['id'] as String] = {
              'email': profile['email'],
              'full_name': profile['full_name'],
              'username': profile['username'],
            };
          }
        } catch (e) {
          debugPrint('EmployeeScreen: Error fetching profiles: $e');
          // Continue without profiles - we'll use fallback data
        }
      }

      // Enrich members (Simplified)
      final enrichedMembers = members.map((m) {
        final roleMatches = rolesData.where((r) => r['id'] == m['role_id']);
        final role = roleMatches.isNotEmpty ? roleMatches.first : {'name': 'Unknown'};
        
        // Get profile data if available
        final userProfile = m['user_id'] != null ? profilesMap[m['user_id'] as String] : null;
        final userEmail = userProfile?['email'] ?? m['invited_email_or_phone'] ?? 'Team Member';
        
        final fullNameStr = userProfile?['full_name']?.toString() ?? '';
        final userName = fullNameStr.trim().isNotEmpty ? fullNameStr : userEmail;
        final usernameStr = userProfile?['username']?.toString() ?? '';
        
        return Map<String, dynamic>.from({
          ...m as Map<String, dynamic>,
          'role_name': role['name'],
          'user_email': userEmail,
          'user_name': userName,
          'username': usernameStr,
        });
      }).toList();

      // Add shop owner to the members list
      final ownerProfile = profilesMap[shop.ownerUserId];
      final ownerRole = rolesData.firstWhere((r) => r['name'] == 'Owner', orElse: () => {'name': 'Owner', 'id': 'owner'});
      
      final ownerMember = {
        'id': 'owner-${shop.ownerUserId}',
        'shop_id': shop.id,
        'user_id': shop.ownerUserId,
        'role_id': ownerRole['id'],
        'role_name': 'Owner',
        'status': 'active',
        'user_email': ownerProfile?['email'] ?? 'Owner',
        'user_name': ownerProfile?['full_name']?.toString() ?? 'Shop Owner',
        'username': ownerProfile?['username']?.toString() ?? '',
        'is_owner': true,
        'created_at': shop.metadata?['created_at'] ?? DateTime.now().toIso8601String(),
      };
      
      // Remove any existing member record for the owner to prevent duplicates
      enrichedMembers.removeWhere((m) => m['user_id'] == shop.ownerUserId);
      
      // Insert owner at the beginning of the list
      enrichedMembers.insert(0, ownerMember);

      // Fetch Invitations (only pending ones)
      debugPrint('EmployeeScreen: Fetching invitations for shop ${shop.id}...');
      final invitesRes = await supabase
          .from('shop_invitations')
          .select('*, roles(name)')
          .eq('shop_id', shop.id)
          .eq('status', 'pending')
          .order('created_at', ascending: false);
      
      debugPrint('EmployeeScreen: Invitations query completed, result: $invitesRes');
      final invitations = invitesRes as List;
      debugPrint('EmployeeScreen: Found ${invitations.length} pending invitations');

      if (mounted) {
        setState(() {
          _roles = rolesData;
          _members = enrichedMembers;
          _invitations = invitations;
          // Pre-select first role for editing
          if (_roles.isNotEmpty && _selectedRoleId == null) {
            Map<String, dynamic>? defaultRoleDoc;
            for (var r in _roles) {
              if (r['name'] == 'Owner') {
                defaultRoleDoc = r as Map<String, dynamic>;
                break;
              }
            }
            defaultRoleDoc ??= _roles.first as Map<String, dynamic>;
            
            _selectedRoleId = defaultRoleDoc['id'];
            _editingPermissions = Map<String, dynamic>.from(defaultRoleDoc['permissions'] ?? {});
          }
          _isLoading = false;
        });
        debugPrint('EmployeeScreen: Data loaded successfully - Roles: ${_roles.length}, Members: ${_members.length}, Invitations: ${_invitations.length}');
      }
    } catch (e, stackTrace) {
      debugPrint('EmployeeScreen: ERROR fetching employee data: $e');
      debugPrint('EmployeeScreen: Stack trace: $stackTrace');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveRolePermissions() async {
    if (_selectedRoleId == null) return;
    
    // Safety: Prevent editing Owner role
    final selectedRole = _roles.firstWhere((r) => r['id'] == _selectedRoleId);
    if (selectedRole['name'] == 'Owner') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Owner permissions are permanent and cannot be changed.')));
      return;
    }

    setState(() => _isSavingRole = true);
    try {
      final shop = context.read<ShopProvider>().currentShop;
      if (shop == null) return;
      
      if (selectedRole['shop_id'] == null) {
        // It's a global role, we must clone it for this shop
        final newRoleRes = await Supabase.instance.client.from('roles').insert({
          'name': selectedRole['name'],
          'description': selectedRole['description'],
          'shop_id': shop.id,
          'permissions': _editingPermissions,
        }).select().single();
        
        final newRoleId = newRoleRes['id'];
        
        // Migrate all members in this shop to the new role
        await Supabase.instance.client.from('shop_members')
            .update({'role_id': newRoleId})
            .eq('shop_id', shop.id)
            .eq('role_id', _selectedRoleId!);
            
        // Migrate all pending invitations in this shop to the new role
        await Supabase.instance.client.from('shop_invitations')
            .update({'role_id': newRoleId})
            .eq('shop_id', shop.id)
            .eq('role_id', _selectedRoleId!);
            
        _selectedRoleId = newRoleId;
      } else {
        // Direct update for custom role
        await Supabase.instance.client
            .from('roles')
            .update({'permissions': _editingPermissions})
            .eq('id', _selectedRoleId!);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Permissions saved successfully!'), backgroundColor: Colors.green));
        _fetchData();
      }
    } catch (e) {
      debugPrint('Error saving role: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSavingRole = false);
    }
  }

  Future<void> _handleInvite() async {
    final email = _inviteEmailController.text.trim();
    if (email.isEmpty || _inviteRoleId == null) return;

    final shopProvider = context.read<ShopProvider>();
    final shopId = shopProvider.currentShop?.id;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (shopId == null || userId == null) return;

    setState(() => _isInviting = true);
    try {
      await Supabase.instance.client.from('shop_invitations').insert({
        'shop_id': shopId,
        'invited_by': userId,
        'invited_email_or_phone': email,
        'role_id': _inviteRoleId,
        'status': 'pending',
      });

      await shopProvider.logActivity(
        action: 'Invite Team Member',
        details: {'message': 'Invited $email to the team'},
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invitation sent!'), backgroundColor: Colors.green));
        _inviteEmailController.clear();
        _inviteRoleId = null;
        Navigator.pop(context);
        _fetchData();
      }
    } catch (e) {
      debugPrint('Error inviting: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isInviting = false);
    }
  }

  Future<void> _toggleMemberStatus(Map<String, dynamic> member) async {
    final isTerminating = member['status'] == 'active';
    final action = isTerminating ? 'Terminate' : 'Reactivate';
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$action Member?'),
        content: Text('Are you sure you want to ${action.toLowerCase()} ${member['user_name'] ?? member['user_email']}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            child: Text(action, style: TextStyle(color: isTerminating ? Colors.red : Colors.green)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await Supabase.instance.client
          .from('shop_members')
          .update({'status': isTerminating ? 'inactive' : 'active'})
          .eq('id', member['id']);
          
      await context.read<ShopProvider>().logActivity(
        action: '${action}d Employee',
        details: {'message': '${action}d ${member['user_name'] ?? member['user_email']}'},
      );

      _fetchData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Member ${isTerminating ? 'terminated' : 'reactivated'} successfully.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  void _showEditRoleDialog(Map<String, dynamic> member) {
    String selectedRoleId = member['role_id'];

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Member Role'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Change role for ${member['user_name'] ?? member['user_email']}'),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedRoleId,
                    decoration: const InputDecoration(labelText: 'Role', border: OutlineInputBorder()),
                    items: _roles.map((r) => DropdownMenuItem(value: r['id'] as String, child: Text(r['name']))).toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setDialogState(() => selectedRoleId = v);
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _updateMemberRole(member, selectedRoleId);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          }
        );
      }
    );
  }

  Future<void> _updateMemberRole(Map<String, dynamic> member, String newRoleId) async {
    try {
      if (member['role_id'] == newRoleId) return;

      await Supabase.instance.client
          .from('shop_members')
          .update({'role_id': newRoleId})
          .eq('id', member['id']);
          
      final roleDetails = _roles.firstWhere((r) => r['id'] == newRoleId, orElse: () => {'name': 'Unknown'});
      
      await context.read<ShopProvider>().logActivity(
        action: 'Updated Employee Role',
        details: {'message': 'Changed role of ${member['user_name'] ?? member['user_email']} to ${roleDetails['name']}'},
      );

      _fetchData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Role updated successfully.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating role: $e'), backgroundColor: Colors.red));
      }
    }
  }

  void _showInviteDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Invite Team Member', style: TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _inviteEmailController,
                    decoration: const InputDecoration(labelText: 'Email or Phone', hintText: 'member@email.com', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _inviteRoleId,
                    decoration: const InputDecoration(labelText: 'Role', border: OutlineInputBorder()),
                    items: _roles.where((r) => r['name'] != 'Owner').map((r) => DropdownMenuItem(value: r['id'] as String, child: Text(r['name']))).toList(),
                    onChanged: (v) => setDialogState(() => _inviteRoleId = v),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: _isInviting ? null : _handleInvite,
                  style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Colors.white),
                  child: Text(_isInviting ? 'Inviting...' : 'Send Invitation'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showTransferOwnershipDialog() {
    // Get all active members except the current owner
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final eligibleMembers = _members.where((m) =>
      m['status'] == 'active' &&
      m['user_id'] != currentUserId &&
      m['is_owner'] != true
    ).toList();

    if (eligibleMembers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No eligible members to transfer ownership to. Add a member first.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    String? selectedMemberId;
    Map<String, dynamic>? selectedMember;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(LucideIcons.alertTriangle, color: Colors.orange),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('Transfer Ownership', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select a team member to transfer shop ownership to. This action requires email verification.',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<Map<String, dynamic>>(
                    decoration: const InputDecoration(
                      labelText: 'New Owner',
                      border: OutlineInputBorder(),
                    ),
                    items: eligibleMembers.map<DropdownMenuItem<Map<String, dynamic>>>((m) {
                      return DropdownMenuItem<Map<String, dynamic>>(
                        value: m as Map<String, dynamic>,
                        child: Text(m['user_name'] ?? m['user_email'] ?? 'Member'),
                      );
                    }).toList(),
                    onChanged: (v) {
                      setDialogState(() {
                        selectedMember = v;
                        selectedMemberId = v?['user_id'];
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: selectedMemberId == null ? null : () {
                    Navigator.pop(context);
                    _showOTPVerificationDialog(selectedMember!);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Continue'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showOTPVerificationDialog(Map<String, dynamic> targetMember) {
    final authProvider = context.read<AuthProvider>();
    final shopProvider = context.read<ShopProvider>();
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final currentUserEmail = Supabase.instance.client.auth.currentUser?.email;
    final shopId = shopProvider.currentShop?.id;

    if (currentUserEmail == null || shopId == null || currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Missing required information'), backgroundColor: Colors.red),
      );
      return;
    }

    final otpController = TextEditingController();
    bool otpSent = false;
    bool isProcessing = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(LucideIcons.mail, color: Colors.orange),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('Email Verification', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!otpSent) ...[
                    const Text(
                      'A verification code will be sent to your email:',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      currentUserEmail,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ] else ...[
                    const Text(
                      'Enter the 6-digit code sent to your email:',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: otpController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 8),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: '000000',
                        counterText: '',
                      ),
                      onChanged: (value) => setDialogState(() {}),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isProcessing ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                if (!otpSent)
                  ElevatedButton(
                    onPressed: isProcessing
                        ? null
                        : () async {
                            setDialogState(() => isProcessing = true);
                            try {
                              await authProvider.sendOwnershipTransferOTP(currentUserEmail);
                              setDialogState(() {
                                otpSent = true;
                                isProcessing = false;
                              });
                            } catch (e) {
                              setDialogState(() => isProcessing = false);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error sending OTP: $e'), backgroundColor: Colors.red),
                                );
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(isProcessing ? 'Sending...' : 'Send Code'),
                  )
                else
                  ElevatedButton(
                    onPressed: isProcessing || otpController.text.length != 6
                        ? null
                        : () async {
                            setDialogState(() => isProcessing = true);
                            try {
                              final result = await authProvider.transferShopOwnership(
                                shopId,
                                currentUserId,
                                targetMember['user_id'],
                                otpController.text.trim(),
                              );

                              if (result['success'] == true) {
                                if (context.mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Ownership transferred successfully!'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                  _fetchData();
                                }
                              } else {
                                setDialogState(() => isProcessing = false);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(result['error'] ?? 'Transfer failed'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            } catch (e) {
                              setDialogState(() => isProcessing = false);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                                );
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(isProcessing ? 'Verifying...' : 'Verify & Transfer'),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Team Management', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (_isOwner || Permissions.hasPermission(context.read<AuthProvider>().currentPermissions, AppPermission.manageEmployees))
            IconButton(
              icon: const Icon(LucideIcons.userPlus),
              onPressed: _showInviteDialog,
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorSize: TabBarIndicatorSize.label,
          tabs: [
            const Tab(icon: Icon(LucideIcons.users, size: 18), text: 'Members'),
            if (_isOwner || Permissions.hasPermission(context.read<AuthProvider>().currentPermissions, AppPermission.manageRoles))
              const Tab(icon: Icon(LucideIcons.shieldCheck, size: 18), text: 'Roles'),
            if (_isOwner || Permissions.hasPermission(context.read<AuthProvider>().currentPermissions, AppPermission.manageEmployees))
              const Tab(icon: Icon(LucideIcons.mail, size: 18), text: 'Invites'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildMembersTab(),
                if (_isOwner || Permissions.hasPermission(context.read<AuthProvider>().currentPermissions, AppPermission.manageRoles))
                  _buildRolesTab(),
                if (_isOwner || Permissions.hasPermission(context.read<AuthProvider>().currentPermissions, AppPermission.manageEmployees))
                  _buildInvitationsTab(),
              ],
            ),
    );
  }

  Widget _buildMembersTab() {
    if (_members.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.users, size: 64, color: Colors.grey.withOpacity(0.3)),
            const SizedBox(height: 16),
            const Text('No team members yet', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _members.length,
      itemBuilder: (context, index) {
        final m = _members[index];
        final isMe = m['user_id'] == Supabase.instance.client.auth.currentUser?.id;
        final status = m['status'] ?? 'active';

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Theme.of(context).dividerColor)),
          child: ListTile(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => EmployeeReportScreen(member: m)));
            },
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              child: Text(m['role_name']?[0] ?? 'M', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
            ),
            title: Text(isMe ? 'You' : m['user_name'] ?? 'Team Member', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (m['username'] != null && m['username'].toString().isNotEmpty)
                  Text('@${m['username']}', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w500)),
                Text(m['user_email'] ?? '', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                const SizedBox(height: 4),
                Text(m['role_name'] ?? 'Member', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: status == 'active' ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(fontSize: 10, color: status == 'active' ? Colors.green : Colors.red, fontWeight: FontWeight.bold),
                  ),
                ),
                if (!isMe && (_isOwner || Permissions.hasPermission(context.read<AuthProvider>().currentPermissions, AppPermission.manageEmployees)))
                  PopupMenuButton<String>(
                    icon: const Icon(LucideIcons.moreVertical, size: 20),
                    onSelected: (value) {
                      if (value == 'edit_role') _showEditRoleDialog(m);
                      else if (value == 'terminate') _toggleMemberStatus(m);
                      else if (value == 'transfer_ownership') _showTransferOwnershipDialog();
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'edit_role', child: Row(children: [Icon(LucideIcons.edit2, size: 16), SizedBox(width: 8), Text('Edit Role')])),
                      PopupMenuItem(
                        value: 'terminate',
                        child: Row(
                          children: [
                            Icon(status == 'active' ? LucideIcons.userX : LucideIcons.userCheck, size: 16, color: status == 'active' ? Colors.red : Colors.green),
                            const SizedBox(width: 8),
                            Text(status == 'active' ? 'Terminate' : 'Reactivate', style: TextStyle(color: status == 'active' ? Colors.red : Colors.green)),
                          ]
                        )
                      ),
                      if (_isOwner)
                        const PopupMenuItem(
                          value: 'transfer_ownership',
                          child: Row(
                            children: [
                              Icon(LucideIcons.arrowRightLeft, size: 16, color: Colors.orange),
                              SizedBox(width: 8),
                              Text('Transfer Ownership', style: TextStyle(color: Colors.orange)),
                            ]
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRolesTab() {
    if (_roles.isEmpty) return const Center(child: Text('No roles defined'));

    Map<String, dynamic>? selectedRole;
    for (var r in _roles) {
      if (r['id'] == _selectedRoleId) {
        selectedRole = r as Map<String, dynamic>;
        break;
      }
    }
    selectedRole ??= _roles.first as Map<String, dynamic>;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('Select Role', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedRoleId,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          ),
          items: _roles.map((r) => DropdownMenuItem(value: r['id'] as String, child: Text(r['name']))).toList(),
          onChanged: (v) {
            setState(() {
              _selectedRoleId = v;
              _editingPermissions = Map<String, dynamic>.from(_roles.firstWhere((r) => r['id'] == v)['permissions'] ?? {});
            });
          },
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.withOpacity(0.1)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(LucideIcons.settings, size: 18, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 10),
                  Text(selectedRole['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              const SizedBox(height: 4),
              Text(selectedRole['description'] ?? 'Configure permissions for this role', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              if (selectedRole['name'] == 'Owner')
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: Colors.amber.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: const Row(
                    children: [
                      Icon(LucideIcons.alertCircle, size: 14, color: Colors.amber),
                      SizedBox(width: 8),
                      Expanded(child: Text('System roles like Owner have permanent full access.', style: TextStyle(fontSize: 11, color: Colors.orange))),
                    ],
                  ),
                ),
              const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider()),
              ..._buildPermissionToggles(isOwnerRole: selectedRole['name'] == 'Owner'),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isSavingRole || !(_isOwner || Permissions.hasPermission(context.read<AuthProvider>().currentPermissions, AppPermission.manageRoles)) || selectedRole['name'] == 'Owner' ? null : _saveRolePermissions,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(_isSavingRole ? 'Saving...' : 'Save Permissions'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildPermissionToggles({bool isOwnerRole = false}) {
    final permissions = [
      {'key': 'create_sale', 'label': 'Create Sale'},
      {'key': 'edit_sale', 'label': 'Edit Sale'},
      {'key': 'delete_sale', 'label': 'Delete Sale'},
      {'key': 'create_purchase', 'label': 'Create Purchase'},
      {'key': 'edit_purchase', 'label': 'Edit Purchase'},
      {'key': 'delete_purchase', 'label': 'Delete Purchase'},
      {'key': 'manage_products', 'label': 'Manage Products'},
      {'key': 'manage_stock', 'label': 'Manage Stock'},
      {'key': 'manage_customers', 'label': 'Manage Customers'},
      {'key': 'manage_suppliers', 'label': 'Manage Suppliers'},
      {'key': 'view_reports', 'label': 'View Reports'},
      {'key': 'manage_employees', 'label': 'Manage Employees'},
      {'key': 'manage_roles', 'label': 'Manage Roles'},
      {'key': 'approve_actions', 'label': 'Approve Actions'},
    ];

    return permissions.map((p) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(p['label']!, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            Switch(
              value: _editingPermissions[p['key']!] == true,
              onChanged: (_isOwner || Permissions.hasPermission(context.read<AuthProvider>().currentPermissions, AppPermission.manageRoles)) && !isOwnerRole 
                ? (v) => setState(() => _editingPermissions[p['key']!] = v) 
                : null,
              activeColor: Theme.of(context).colorScheme.primary,
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildInvitationsTab() {
    if (_invitations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.mail, size: 64, color: Colors.grey.withOpacity(0.3)),
            const SizedBox(height: 16),
            const Text('No pending invitations', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _invitations.length,
      itemBuilder: (context, index) {
        final i = _invitations[index];
        final status = i['status'] ?? 'pending';
        final role = i['roles']?['name'] ?? 'Member';

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Theme.of(context).dividerColor)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue.withOpacity(0.1),
              child: const Icon(LucideIcons.mail, color: Colors.blue, size: 20),
            ),
            title: Text(i['invited_email_or_phone'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Text('Role: $role • ${status.toUpperCase()}', style: const TextStyle(fontSize: 11)),
            trailing: status == 'pending' ? IconButton(
              icon: const Icon(LucideIcons.x, color: Colors.red, size: 18),
              onPressed: () => _cancelInvitation(i['id']),
            ) : null,
          ),
        );
      },
    );
  }

  Future<void> _cancelInvitation(String id) async {
    try {
      await Supabase.instance.client
          .from('shop_invitations')
          .update({'status': 'expired'})
          .eq('id', id);
      _fetchData();
    } catch (e) {
      debugPrint('Error cancelling invitation: $e');
    }
  }
}

