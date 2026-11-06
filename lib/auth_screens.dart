
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_service.dart';

final authService = AuthService();

String authError(Object error) {
  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'invalid-email':
        return 'Please enter a valid email.';
      case 'weak-password':
        return 'Please choose a stronger password.';
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'wrong-password':
      case 'invalid-credential':
      case 'user-not-found':
        return 'Invalid email or password.';
      case 'too-many-requests':
        return 'Too many attempts. Try again later.';
      case 'network-request-failed':
        return 'Check your internet connection.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }
  return 'Something went wrong. Please try again.';
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(child: Text('Unable to check sign-in status.')),
          );
        }
        return snapshot.hasData
            ? const ProfileScreen()
            : const AuthenticationScreen();
      },
    );
  }
}

class AuthenticationScreen extends StatefulWidget {
  const AuthenticationScreen({super.key});

  @override
  State<AuthenticationScreen> createState() => _AuthenticationScreenState();
}

class _AuthenticationScreenState extends State<AuthenticationScreen> {
  final formKey = GlobalKey<FormState>();
  final email = TextEditingController();
  final password = TextEditingController();
  bool registering = false;
  bool loading = false;
  String? message;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!formKey.currentState!.validate() || loading) return;

    setState(() {
      loading = true;
      message = null;
    });

    try {
      if (registering) {
        await authService.register(email.text, password.text);
      } else {
        await authService.signIn(email.text, password.text);
      }
    } catch (e) {
      if (mounted) setState(() => message = authError(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Firebase Authentication')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  registering ? 'Create Account' : 'Sign In',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: email,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null ||
                        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                            .hasMatch(value.trim())) {
                      return 'Enter a valid email';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: password,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                  validator: (value) =>
                      value == null || value.length < 6
                          ? 'Password must be at least 6 characters'
                          : null,
                ),
                const SizedBox(height: 20),
                if (message != null)
                  Text(message!, style: const TextStyle(color: Colors.red)),
                if (loading) const CircularProgressIndicator(),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: loading ? null : submit,
                  child: Text(registering ? 'Register' : 'Sign In'),
                ),
                TextButton(
                  onPressed: loading
                      ? null
                      : () => setState(() {
                            registering = !registering;
                            message = null;
                          }),
                  child: Text(registering
                      ? 'Already have an account? Sign In'
                      : 'Need an account? Register'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final currentPassword = TextEditingController();
  final newPassword = TextEditingController();
  bool loading = false;
  String? message;

  @override
  void dispose() {
    currentPassword.dispose();
    newPassword.dispose();
    super.dispose();
  }

  Future<void> changePassword() async {
    if (loading) return;

    if (currentPassword.text.isEmpty || newPassword.text.length < 6) {
      setState(() => message =
          'Enter your current password and a new password of at least 6 characters.');
      return;
    }

    setState(() {
      loading = true;
      message = null;
    });

    try {
      await authService.updatePassword(
        currentPassword.text,
        newPassword.text,
      );
      currentPassword.clear();
      newPassword.clear();
      if (mounted) {
        setState(() => message = 'Password updated successfully!');
      }
    } catch (e) {
      if (mounted) setState(() => message = authError(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.account_circle, size: 70),
              const SizedBox(height: 12),
              const Text('Signed in as:'),
              Text(
                authService.currentUser?.email ?? 'Unknown',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 30),
              const Text('Change Password'),
              TextField(
                controller: currentPassword,
                obscureText: true,
                decoration:
                    const InputDecoration(labelText: 'Current Password'),
              ),
              TextField(
                controller: newPassword,
                obscureText: true,
                decoration:
                    const InputDecoration(labelText: 'New Password'),
              ),
              const SizedBox(height: 15),
              if (message != null) Text(message!),
              if (loading) const CircularProgressIndicator(),
              ElevatedButton(
                onPressed: loading ? null : changePassword,
                child: const Text('Update Password'),
              ),
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: loading ? null : () async {
                  try {
                    await authService.signOut();
                  } catch (e) {
                    if (mounted) {
                      setState(() => message = authError(e));
                    }
                  }
                },
                child: const Text('Sign Out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
