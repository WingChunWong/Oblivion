import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/account_service.dart';
import '../models/account.dart';
import '../l10n/app_localizations.dart';

class AccountsScreen extends StatelessWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final accountService = context.watch<AccountService>();
    final accounts = accountService.accounts;
    final selectedId = accountService.selectedAccount?.id;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.get('account_management'), style: Theme.of(context).textTheme.headlineMedium),
              FilledButton.icon(
                onPressed: () => _showAddAccountDialog(context),
                icon: const Icon(Icons.add),
                label: Text(l10n.get('add_account')),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: accounts.isEmpty
                ? _buildEmptyState(context, l10n)
                : _buildAccountList(context, accounts, selectedId, accountService, l10n),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(Icons.person_off, size: 40, color: Theme.of(context).colorScheme.outline),
          ),
          const SizedBox(height: 16),
          Text(l10n.get('no_accounts'), style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(l10n.get('add_account_hint')),
        ],
      ),
    );
  }

  Widget _buildAccountList(BuildContext context, List<Account> accounts, String? selectedId, AccountService service, AppLocalizations l10n) {
    return ListView.builder(
      itemCount: accounts.length,
      itemBuilder: (context, index) {
        final account = accounts[index];
        final isSelected = account.id == selectedId;
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          color: isSelected ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3) : null,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Icon(
                _getAccountIcon(account.type),
                color: isSelected ? Theme.of(context).colorScheme.onPrimary : null,
              ),
            ),
            title: Text(account.username),
            subtitle: Text(_getAccountTypeName(account.type, l10n) + 
                (account.authlibServer != null ? ' • ${account.authlibServer}' : '')),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(l10n.get('current'), style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontSize: 12,
                    )),
                  ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _confirmDelete(context, account, service, l10n),
                ),
              ],
            ),
            onTap: () => service.selectAccount(account.id),
          ),
        );
      },
    );
  }

  IconData _getAccountIcon(AccountType type) => switch (type) {
    AccountType.offline => Icons.person,
    AccountType.microsoft => Icons.window,
    AccountType.authlibInjector => Icons.vpn_key,
  };

  String _getAccountTypeName(AccountType type, AppLocalizations l10n) => switch (type) {
    AccountType.offline => l10n.get('offline_account'),
    AccountType.microsoft => l10n.get('microsoft_account'),
    AccountType.authlibInjector => l10n.get('authlib_account'),
  };

  void _showAddAccountDialog(BuildContext context) {
    showDialog(context: context, builder: (context) => const _AddAccountDialog());
  }

  void _confirmDelete(BuildContext context, Account account, AccountService service, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.get('delete_account')),
        content: Text('${l10n.get('delete_account_confirm')} "${account.username}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.get('cancel'))),
          FilledButton(
            onPressed: () {
              service.removeAccount(account.id);
              Navigator.pop(context);
            },
            child: Text(l10n.get('delete')),
          ),
        ],
      ),
    );
  }
}

class _AddAccountDialog extends StatefulWidget {
  const _AddAccountDialog();

  @override
  State<_AddAccountDialog> createState() => _AddAccountDialogState();
}

class _AddAccountDialogState extends State<_AddAccountDialog> {
  int _selectedType = 0;
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _serverController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _serverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.get('add_account')),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SegmentedButton<int>(
              segments: [
                ButtonSegment(value: 0, label: Text(l10n.get('offline')), icon: const Icon(Icons.person)),
                ButtonSegment(value: 1, label: Text(l10n.get('microsoft')), icon: const Icon(Icons.window)),
                ButtonSegment(value: 2, label: Text(l10n.get('authlib')), icon: const Icon(Icons.vpn_key)),
              ],
              selected: {_selectedType},
              onSelectionChanged: (set) => setState(() {
                _selectedType = set.first;
                _error = null;
              }),
            ),
            const SizedBox(height: 20),
            if (_selectedType == 0) _buildOfflineForm(l10n),
            if (_selectedType == 1) _buildMicrosoftForm(l10n),
            if (_selectedType == 2) _buildAuthlibForm(l10n),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.get('cancel'))),
        FilledButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(_selectedType == 1 ? l10n.get('login') : l10n.get('add')),
        ),
      ],
    );
  }

  Widget _buildOfflineForm(AppLocalizations l10n) {
    return TextField(
      controller: _usernameController,
      decoration: InputDecoration(
        labelText: l10n.get('username'),
        hintText: l10n.get('username_hint'),
      ),
      autofocus: true,
    );
  }

  Widget _buildMicrosoftForm(AppLocalizations l10n) {
    return Column(
      children: [
        const Icon(Icons.open_in_browser, size: 48),
        const SizedBox(height: 12),
        Text(l10n.get('microsoft_login_instruction')),
      ],
    );
  }

  Widget _buildAuthlibForm(AppLocalizations l10n) {
    
    final commonServers = [
      {'name': 'LittleSkin', 'url': 'https://littleskin.cn/api/yggdrasil'},
      {'name': 'Blessing Skin', 'url': 'https://skin.prinzeugen.net/api/yggdrasil'},
      {'name': '自定义', 'url': ''},
    ];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        
        Text(l10n.get('auth_server'), style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: commonServers.map((server) {
            final isSelected = _serverController.text == server['url'];
            return FilterChip(
              label: Text(server['name']!),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _serverController.text = server['url']!;
                  });
                }
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        
        TextField(
          controller: _serverController,
          decoration: InputDecoration(
            labelText: l10n.get('server_url'),
            hintText: 'https://example.com/api/yggdrasil',
            helperText: '支持 authlib-injector 协议的皮肤站',
            prefixIcon: const Icon(Icons.link),
            suffixIcon: _serverController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(() => _serverController.clear()),
                  )
                : null,
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        
        TextField(
          controller: _usernameController,
          decoration: InputDecoration(
            labelText: l10n.get('email_username'),
            hintText: '邮箱或用户名',
            prefixIcon: const Icon(Icons.person),
          ),
          autofocus: false,
        ),
        const SizedBox(height: 12),
        
        TextField(
          controller: _passwordController,
          decoration: InputDecoration(
            labelText: l10n.get('password'),
            prefixIcon: const Icon(Icons.lock),
          ),
          obscureText: true,
          onSubmitted: (_) => _submit(),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final accountService = context.read<AccountService>();
    
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      switch (_selectedType) {
        case 0: 
          final username = _usernameController.text.trim();
          if (username.isEmpty) {
            setState(() => _error = l10n.get('error_empty_username'));
            return;
          }
          await accountService.addOfflineAccount(username);
          break;
          
        case 1: 
          await accountService.loginMicrosoft();
          break;
          
        case 2: 
          final server = _serverController.text.trim();
          final username = _usernameController.text.trim();
          final password = _passwordController.text;
          
          if (server.isEmpty) {
            setState(() => _error = l10n.get('error_empty_server'));
            return;
          }
          if (username.isEmpty || password.isEmpty) {
            setState(() => _error = l10n.get('error_empty_credentials'));
            return;
          }
          
          await accountService.loginAuthlib(server, username, password);
          break;
      }
      
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
