import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../auth.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  String? errorMessage = '';
  String? successMessage = '';
  bool isLoading = false;

  final TextEditingController _controllerEmail = TextEditingController();

  Future<void> sendPasswordReset() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
      successMessage = '';
    });

    try {
      await Auth().sendPasswordReset(email: _controllerEmail.text);
      setState(() {
        successMessage =
            'Password reset email sent! Check your email to reset your password.';
        _controllerEmail.clear();
      });
    } on FirebaseAuthException catch (e) {
      setState(() {
        errorMessage = e.message;
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Widget _title() {
    return const Text('Forgot Password');
  }

  Widget _entryField(String title, TextEditingController controller) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(labelText: title),
    );
  }

  Widget _errorMessage() {
    return Text(
      errorMessage == '' ? '' : 'Error: $errorMessage',
      style: const TextStyle(color: Colors.red),
    );
  }

  Widget _successMessage() {
    return Text(
      successMessage ?? '',
      style: const TextStyle(color: Colors.green),
    );
  }

  Widget _resetButton() {
    return ElevatedButton(
      onPressed: isLoading ? null : sendPasswordReset,
      child: isLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Text('Reset Password'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _title(),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        height: double.infinity,
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'Enter your email to receive a password reset link',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            _entryField('email', _controllerEmail),
            const SizedBox(height: 10),
            _errorMessage(),
            _successMessage(),
            const SizedBox(height: 20),
            _resetButton(),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controllerEmail.dispose();
    super.dispose();
  }
}
