import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/primary_button.dart';
import 'account_provider.dart';

/// Google or email sign-in, and creating an account.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _creating = false;
  bool _busy = false;
  bool _showPassword = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (mounted) Navigator.of(context).pop(true);
    } on AccountError catch (e) {
      setState(() => _error = e.message);
    } on GoogleSignInException catch (e) {
      if (e.code != GoogleSignInExceptionCode.canceled) {
        setState(() => _error = "Google sign-in didn't work (${e.code.name}). Try again or use email.");
      }
    } catch (e) {
      setState(() => _error = 'Something went wrong: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _emailAction() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Enter your email and a password.');
      return;
    }
    final account = context.read<AccountProvider>();
    await _run(() => _creating ? account.createAccount(email, password) : account.signInWithEmail(email, password));
  }

  Future<void> _forgotPassword() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Type your email above first, then tap "Forgot password".');
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<AccountProvider>().sendPasswordReset(email);
      messenger.showSnackBar(SnackBar(content: Text('Password reset link sent to $email.')));
    } on AccountError catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = context.read<AccountProvider>();
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            Text(_creating ? 'CREATE ACCOUNT' : 'SIGN IN', style: AppText.display(38)),
            const SizedBox(height: 6),
            const Text(
              'Back up your training and use it on any phone. Everything keeps working offline.',
              style: AppText.muted,
            ),
            const SizedBox(height: 24),
            if (!account.available)
              const Text('Sign-in is unavailable right now.', style: AppText.muted)
            else ...[
              SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : () => _run(account.signInWithGoogle),
                  icon: const Text('G', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  label: const Text('Continue with Google'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.text,
                    side: const BorderSide(color: AppColors.border),
                    shape: const StadiumBorder(),
                    textStyle: const TextStyle(fontFamily: AppFonts.body, fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('or with email', style: AppText.muted),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                autocorrect: false,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _password,
                obscureText: !_showPassword,
                autofillHints: [_creating ? AutofillHints.newPassword : AutofillHints.password],
                decoration: InputDecoration(
                  labelText: 'Password',
                  helperText: _creating ? 'At least 6 characters' : null,
                  suffixIcon: IconButton(
                    tooltip: _showPassword ? 'Hide password' : 'Show password',
                    icon: Icon(_showPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                    onPressed: () => setState(() => _showPassword = !_showPassword),
                  ),
                ),
                onSubmitted: (_) => _emailAction(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600)),
              ],
              const SizedBox(height: 20),
              PrimaryButton(
                text: _busy ? 'Please wait…' : (_creating ? 'Create account' : 'Sign in'),
                isLarge: true,
                onPressed: _busy ? null : _emailAction,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: _busy ? null : () => setState(() => _creating = !_creating),
                    child: Text(_creating ? 'I have an account' : 'Create an account'),
                  ),
                  if (!_creating)
                    TextButton(
                      onPressed: _busy ? null : _forgotPassword,
                      style: TextButton.styleFrom(foregroundColor: AppColors.textMuted),
                      child: const Text('Forgot password'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
