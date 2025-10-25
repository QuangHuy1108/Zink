// lib/login_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'session_manager.dart'; // Quản lý trạng thái đăng nhập cục bộ
import 'home_screen.dart'; // Màn hình chính sau khi đăng nhập
import 'register_screen.dart'; // Màn hình đăng ký

// Constants (Giữ nguyên)
const Color topazColor = Color(0xFFF6C886);
const Color sonicSilver = Color(0xFF747579);
const Color darkSurface = Color(0xFF1E1E1E);
const Color coralRed = Color(0xFFFD402C); // Added for error messages

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailOrPhoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _errorMessage;
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _isEmailSelected = true;

  // Hàm thực hiện đăng nhập (Giữ nguyên logic Firebase)
  void _performLogin() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });
    final input = _emailOrPhoneController.text.trim();
    final password = _passwordController.text.trim();

    if (input.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'Vui lòng điền đầy đủ thông tin.';
        _isLoading = false;
      });
      return;
    }

    try {
      if (!_isEmailSelected) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Chức năng đăng nhập bằng SĐT chưa được triển khai.'),
              backgroundColor: sonicSilver,
            ),
          );
        }
        setState(() {
          _isLoading = false;
        });
        return;
      }

      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
          email: input, password: password);
      if (userCredential.user != null) {
        await SessionManager().createLoginSession();
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        }
        return;
      } else {
        throw FirebaseAuthException(
            code: 'null-user', message: 'Không thể lấy thông tin người dùng.');
      }
    } on FirebaseAuthException catch (e) {
      String friendlyErrorMessage;
      switch (e.code) {
        case 'user-not-found':
          friendlyErrorMessage = 'Không tìm thấy tài khoản với email này.';
          break;
        case 'wrong-password':
          friendlyErrorMessage = 'Sai mật khẩu. Vui lòng thử lại.';
          break;
        default:
          friendlyErrorMessage =
          'Đã xảy ra lỗi khi đăng nhập. Vui lòng thử lại.';
      }
      setState(() {
        _errorMessage = friendlyErrorMessage;
      });
    } catch (e) {
      print("Login Error: $e");
      setState(() {
        _errorMessage = 'Đã xảy ra lỗi không xác định.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _emailOrPhoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Widget _buildSocialButton(String label, IconData icon, Color iconColor) {
    return Expanded(
      child: OutlinedButton.icon(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Chức năng đăng nhập bằng $label chưa được triển khai.'),
              backgroundColor: sonicSilver,
            ),
          );
        },
        icon: Icon(icon, color: iconColor, size: 24),
        label: Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 15),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: sonicSilver),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildToggleButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? topazColor : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: topazColor),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.black : Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
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
              const Text(
                'Chào mừng trở lại',
                style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
              const SizedBox(height: 8),
              const Text(
                'Vui lòng đăng nhập vào tài khoản của bạn',
                style: TextStyle(fontSize: 16, color: sonicSilver),
              ),
              const SizedBox(height: 40),

              // Toggle Email / Phone
              Row(
                children: [
                  _buildToggleButton(
                    label: 'Email',
                    isSelected: _isEmailSelected,
                    onTap: () {
                      setState(() {
                        _isEmailSelected = true;
                      });
                    },
                  ),
                  const SizedBox(width: 10),
                  _buildToggleButton(
                    label: 'SĐT',
                    isSelected: !_isEmailSelected,
                    onTap: () {
                      setState(() {
                        _isEmailSelected = false;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 25),

              // Input fields
              TextField(
                controller: _emailOrPhoneController,
                decoration: InputDecoration(
                  hintText: _isEmailSelected ? 'Email' : 'Số điện thoại',
                  hintStyle: const TextStyle(color: sonicSilver),
                  filled: true,
                  fillColor: darkSurface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                keyboardType:
                _isEmailSelected ? TextInputType.emailAddress : TextInputType.phone,
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
              const SizedBox(height: 12),

              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {},
                  child: const Text(
                    'Quên mật khẩu?',
                    style: TextStyle(color: topazColor),
                  ),
                ),
              ),

              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: coralRed, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),

              _isLoading
                  ? const Center(
                child: CircularProgressIndicator(color: topazColor),
              )
                  : ElevatedButton(
                onPressed: _performLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: topazColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text(
                  'Đăng nhập',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
                ),
              ),

              const SizedBox(height: 30),

              // Divider "Hoặc đăng nhập với"
              Row(
                children: const [
                  Expanded(child: Divider(color: sonicSilver)),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(
                      'Hoặc đăng nhập với',
                      style: TextStyle(color: sonicSilver),
                    ),
                  ),
                  Expanded(child: Divider(color: sonicSilver)),
                ],
              ),
              const SizedBox(height: 25),

              Row(
                children: [
                  _buildSocialButton('Google', Icons.g_mobiledata_outlined, Colors.white),
                ],
              ),
              const SizedBox(height: 35),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Chưa có tài khoản? ',
                    style: TextStyle(color: sonicSilver),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const RegisterScreen()),
                      );
                    },
                    child: const Text(
                      'Đăng ký ngay',
                      style: TextStyle(
                          color: topazColor, fontWeight: FontWeight.bold),
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
