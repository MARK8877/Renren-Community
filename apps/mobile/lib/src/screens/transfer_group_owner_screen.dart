import 'package:flutter/material.dart';

import '../auth/auth_session.dart';
import '../chat/chat_api.dart';
import '../widgets/chat_avatar.dart';

class TransferGroupOwnerScreen extends StatefulWidget {
  const TransferGroupOwnerScreen({
    super.key,
    required this.session,
    required this.conversationId,
    required this.members,
    required this.chatApi,
  });

  final AuthSession session;
  final String conversationId;
  final List<GroupMemberData> members;
  final ChatApi chatApi;

  @override
  State<TransferGroupOwnerScreen> createState() =>
      _TransferGroupOwnerScreenState();
}

class _TransferGroupOwnerScreenState extends State<TransferGroupOwnerScreen> {
  int? selectedUserId;
  bool submitting = false;

  List<GroupMemberData> get candidates =>
      widget.members.where((member) => member.role != 'owner').toList();

  Future<void> submit() async {
    final userId = selectedUserId;
    if (userId == null || submitting) return;
    final target = candidates.firstWhere((member) => member.userId == userId);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('transfer-owner-dialog'),
        title: const Text('确认转让群主？'),
        content: Text('将群主转让给 ${target.nickname}？转让后你将成为普通成员。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('再想想'),
          ),
          FilledButton(
            key: const Key('confirm-transfer-owner-dialog'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认转让'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => submitting = true);
    try {
      final token = widget.session.accessToken;
      if (token != null) {
        await widget.chatApi.transferGroupOwner(
          token,
          widget.conversationId,
          userId,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ChatApiException catch (error) {
      if (mounted) showMessage(error.message);
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const Key('transfer-group-owner-screen'),
    backgroundColor: const Color(0xFFF5F6F8),
    appBar: AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 0,
      title: const Text('转让群主', style: TextStyle(fontWeight: FontWeight.w700)),
    ),
    body: Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E8),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, color: Color(0xFFB7791F)),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '转让后你将变为普通成员，群主权限会立即交给新群主，此操作不可撤销。',
                        style: TextStyle(
                          color: Color(0xFF805B17),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                '选择新群主',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              if (candidates.isEmpty)
                Container(
                  key: const Key('transfer-owner-empty-state'),
                  padding: const EdgeInsets.symmetric(vertical: 36),
                  alignment: Alignment.center,
                  child: const Text(
                    '暂无可转让成员',
                    style: TextStyle(color: Color(0xFF858B95)),
                  ),
                )
              else
                ...candidates.map(
                  (member) => _CandidateTile(
                    key: Key('transfer-owner-member-${member.userId}'),
                    member: member,
                    selected: selectedUserId == member.userId,
                    onTap: submitting
                        ? null
                        : () => setState(
                            () => selectedUserId = member.userId,
                          ),
                  ),
                ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                key: const Key('confirm-transfer-owner'),
                onPressed: selectedUserId == null || submitting ? null : submit,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF6256E8),
                  disabledBackgroundColor: const Color(0xFFE1E2E8),
                  disabledForegroundColor: const Color(0xFF9EA1AD),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(submitting ? '转让中…' : '确认转让群主'),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _CandidateTile extends StatelessWidget {
  const _CandidateTile({
    super.key,
    required this.member,
    required this.selected,
    required this.onTap,
  });

  final GroupMemberData member;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: BorderSide(
        color: selected ? const Color(0xFF6256E8) : const Color(0xFFE7E8ED),
        width: selected ? 1.5 : 1,
      ),
    ),
    clipBehavior: Clip.antiAlias,
    child: ListTile(
      onTap: onTap,
      leading: ChatAvatar.person(name: member.nickname, radius: 22),
      title: Text(member.nickname),
      subtitle: Text(member.role == 'admin' ? '管理员' : '普通成员'),
      trailing: Icon(
        selected
            ? Icons.radio_button_checked_rounded
            : Icons.radio_button_off_rounded,
        color: selected ? const Color(0xFF6256E8) : const Color(0xFFB5B8C2),
      ),
    ),
  );
}
