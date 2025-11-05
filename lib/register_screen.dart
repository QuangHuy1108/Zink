// lib/register_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_screen.dart'; // Để quay lại sau khi đăng ký

// Constants (Giữ nguyên)
const Color topazColor = Color(0xFFF6C886);
const Color sonicSilver = Color(0xFF747579);
const Color darkSurface = Color(0xFF1E1E1E);
const Color coralRed = Color(0xFFFD402C); // Màu cho lỗi
const Color activeGreen = Color(0xFF4CAF50); // Màu xanh lá cho thành công

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _emailOrPhoneController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _errorMessage;
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  void _performRegistration() async {
    FocusScope.of(context).unfocus();
    setState(() { _errorMessage = null; _isLoading = true; });
    final input = _emailOrPhoneController.text.trim();
    final name = _nameController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    // --- VALIDATION ---
    if (input.isEmpty || name.isEmpty || username.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      setState(() { _errorMessage = 'Vui lòng điền đầy đủ thông tin.'; _isLoading = false; });
      return;
    }
    if (password != confirmPassword) {
      setState(() { _errorMessage = 'Mật khẩu xác nhận không khớp.'; _isLoading = false; });
      return;
    }
    if (!input.contains('@')) {
      setState(() { _errorMessage = 'Địa chỉ email không hợp lệ.'; _isLoading = false; });
      return;
    }
    if (username.contains(' ') || username.length < 3) {
      setState(() { _errorMessage = 'Tên đăng nhập không hợp lệ.'; _isLoading = false; });
      return;
    }

    try {
      final existingUsername = await _firestore.collection('users')
          .where('usernameLower', isEqualTo: username.toLowerCase())
          .limit(1)
          .get();
      if (existingUsername.docs.isNotEmpty) {
        setState(() { _errorMessage = 'Tên đăng nhập đã tồn tại. Vui lòng chọn tên khác.'; _isLoading = false; });
        return;
      }

      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(email: input, password: password);
      User? user = userCredential.user;

      if (user != null) {
        // --- START: ROBUST SEQUENTIAL REGISTRATION LOGIC ---
        // 1. Update Auth profile and WAIT for it to complete.
        await user.updateDisplayName(name);

        // 2. Reload the user state from the backend to ensure the local instance is up-to-date.
        await user.reload();

        // 3. Get the freshest instance of the user.
        User? freshUser = _auth.currentUser;

        if (freshUser != null) {
            // 4. Write to Firestore using the reloaded, guaranteed-fresh data.
            await _firestore.collection('users').doc(freshUser.uid).set({
              'uid': freshUser.uid,
              'email': freshUser.email,
              'displayName': freshUser.displayName, // Use the fresh data from Auth
              'photoURL': freshUser.photoURL,
              'username': username,
              'nameLower': name.toLowerCase(),
              'usernameLower': username.toLowerCase(),
              'title': '',
              'coverImageUrl': null,
              'createdAt': FieldValue.serverTimestamp(),
              'phone': null,
              'followers': [],
              'following': [],
              'friendUids': [],
              'postsCount': 0,
              'totalLikes': 0,
            });
        } else {
            // This case is highly unlikely but a good safeguard.
            throw Exception("Failed to get fresh user instance after reload.");
        }
        // --- END: ROBUST SEQUENTIAL REGISTRATION LOGIC ---

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tạo tài khoản thành công! Vui lòng đăng nhập.'), backgroundColor: activeGreen));
          Navigator.pop(context);
        }
      } else {
        throw FirebaseAuthException(code: 'null-user', message: 'Không thể tạo người dùng.');
      }
    } on FirebaseAuthException catch (e) {
      String friendlyErrorMessage;
      if (e.code == 'email-already-in-use') {
        friendlyErrorMessage = 'Địa chỉ email này đã được sử dụng.';
      } else {
        friendlyErrorMessage = 'Đã xảy ra lỗi khi đăng ký. Vui lòng thử lại.';
      }
      setState(() { _errorMessage = friendlyErrorMessage; });
    } catch (e) {
      print("Register Error: $e");
      setState(() { _errorMessage = 'Đã xảy ra lỗi không xác định.'; });
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  @override
  void dispose() {
    _emailOrPhoneController.dispose();
    _nameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                  onPressed: () => Navigator.pop(context),
                  splashRadius: 28,
                ),
              ),
              const SizedBox(height: 20),
              const Text('Tạo tài khoản', style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 8),
              Text('Nhập thông tin cá nhân của bạn', style: TextStyle(fontSize: 16, color: sonicSilver.withOpacity(0.8))),
              const SizedBox(height: 30),
              const SizedBox(height: 25),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: 'Họ và tên',
                  hintStyle: const TextStyle(color: sonicSilver),
                  filled: true,
                  fillColor: darkSurface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                keyboardType: TextInputType.text,
              ),
              const Padding(
                padding: EdgeInsets.only(top: 8.0, bottom: 16.0, left: 4.0),
                child: Text(
                  'Đây là tên hiển thị trên trang cá nhân của bạn.',
                  style: TextStyle(color: sonicSilver, fontSize: 12),
                ),
              ),
              TextField(
                controller: _usernameController,
                decoration: InputDecoration(
                  hintText: 'Tên đăng nhập (Username)',
                  hintStyle: const TextStyle(color: sonicSilver),
                  filled: true,
                  fillColor: darkSurface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                keyboardType: TextInputType.text,
              ),
              const Padding(
                padding: EdgeInsets.only(top: 8.0, bottom: 16.0, left: 4.0),
                child: Text(
                  'Tên đăng nhập sẽ là duy nhất và không được chứa khoảng trắng.',
                  style: TextStyle(color: sonicSilver, fontSize: 12),
                ),
              ),
              TextField(
                controller: _emailOrPhoneController,
                decoration: InputDecoration(
                  hintText: 'Email',
                  hintStyle: const TextStyle(color: sonicSilver),
                  filled: true,
                  fillColor: darkSurface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const Padding(
                padding: EdgeInsets.only(top: 8.0, left: 4.0),
                child: Text(
                  'Sử dụng địa chỉ email hợp lệ để nhận thông báo.',
                  style: TextStyle(color: sonicSilver, fontSize: 12),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: !_isPasswordVisible,
                decoration: InputDecoration(
                  hintText: 'Mật khẩu',
                  hintStyle: const TextStyle(color: sonicSilver),
                  filled: true,
                  fillColor: darkSurface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                      color: sonicSilver,
                    ),
                    onPressed: () {
                      setState(() {
                        _isPasswordVisible = !_isPasswordVisible;
                      });
                    },
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 8.0, left: 4.0),
                child: Text(
                  'Mật khẩu phải có ít nhất 6 ký tự.',
                  style: TextStyle(color: sonicSilver, fontSize: 12),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _confirmPasswordController,
                obscureText: !_isConfirmPasswordVisible,
                decoration: InputDecoration(
                  hintText: 'Xác nhận mật khẩu',
                  hintStyle: const TextStyle(color: sonicSilver),
                  filled: true,
                  fillColor: darkSurface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isConfirmPasswordVisible ? Icons.visibility_off : Icons.visibility,
                      color: sonicSilver,
                    ),
                    onPressed: () {
                      setState(() {
                        _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: coralRed, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: topazColor))
                    : ElevatedButton(
                  onPressed: _performRegistration,
                  child: const Text('Đăng ký', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 25),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Đã có tài khoản? ', style: TextStyle(color: sonicSilver)),
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context); // Quay lại màn hình Login
                    },
                    child: const Text(
                      'Đăng nhập ngay',
                      style: TextStyle(color: topazColor, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
