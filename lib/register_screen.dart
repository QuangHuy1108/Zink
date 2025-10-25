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
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _errorMessage;
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isEmailSelected = true;

  // Hàm thực hiện đăng ký (Giữ nguyên logic Firebase)
  void _performRegistration() async {
    FocusScope.of(context).unfocus();
    setState(() { _errorMessage = null; _isLoading = true; });
    final input = _emailOrPhoneController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    // --- VALIDATION (Giữ nguyên) ---
    if (input.isEmpty || password.isEmpty || confirmPassword.isEmpty) { /* Handle empty fields */ setState(() { _errorMessage = 'Vui lòng điền đầy đủ thông tin.'; _isLoading = false; }); return; }
    if (password != confirmPassword) { /* Handle password mismatch */ setState(() { _errorMessage = 'Mật khẩu xác nhận không khớp.'; _isLoading = false; }); return; }
    if (_isEmailSelected && !input.contains('@')) { /* Handle invalid email */ setState(() { _errorMessage = 'Địa chỉ email không hợp lệ.'; _isLoading = false; }); return; }

    // --- XỬ LÝ ĐĂNG KÝ BẰNG SỐ ĐIỆN THOẠI (PLACEHOLDER - Giữ nguyên) ---
    if (!_isEmailSelected) { /* Handle phone registration placeholder */ setState(() { _isLoading = false; }); return; }

    // ---- XỬ LÝ ĐĂNG KÝ BẰNG EMAIL/PASSWORD (Firebase Auth & Firestore - Giữ nguyên) ----
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(email: input, password: password);
      User? user = userCredential.user;
      if (user != null) {
        // Create user doc in Firestore
        final emailParts = input.split('@');
        final defaultUsername = emailParts[0].replaceAll('.', '').toLowerCase();
        final defaultName = emailParts[0];
        await _firestore.collection('users').doc(user.uid).set({
          'uid': user.uid, 'email': input, 'name': defaultName, 'username': defaultUsername,
          'nameLower': defaultName.toLowerCase(), 'usernameLower': defaultUsername,
          'title': '', 'avatarUrl': null, 'coverImageUrl': null,
          'createdAt': FieldValue.serverTimestamp(), 'phone': null,
          'followers': [], 'following': [], 'friendUids': [],
          'postsCount': 0, 'totalLikes': 0,
        });
        // await user.updateDisplayName(defaultName); // Optional: Update Firebase Auth profile

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tạo tài khoản thành công! Vui lòng đăng nhập.'), backgroundColor: activeGreen));
          Navigator.pop(context); // Go back to LoginScreen
          return;
        }
      } else { throw FirebaseAuthException(code: 'null-user', message: 'Không thể tạo người dùng.'); }
    } on FirebaseAuthException catch (e) { /* Handle Firebase Auth errors */ String friendlyErrorMessage; switch (e.code) { /* ... cases ... */ default: friendlyErrorMessage = 'Đã xảy ra lỗi khi đăng ký. Vui lòng thử lại.'; } setState(() { _errorMessage = friendlyErrorMessage; }); }
    catch (e) { /* Handle other errors */ print("Register Error: $e"); setState(() { _errorMessage = 'Đã xảy ra lỗi không xác định.'; }); }
    finally { if (mounted) setState(() { _isLoading = false; }); }
  }

  @override
  void dispose() {
    _emailOrPhoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // Widget cho nút chuyển đổi Email/Phone (Giữ nguyên UI)
// Widget cho nút chuyển đổi Email/Phone
  Widget _buildToggleButton({required String label, required bool isSelected, required VoidCallback onTap}) {
    return Expanded(
      // Sửa lỗi: Thêm child
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? darkSurface : Colors.black, // Màu nền nút
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? darkSurface : sonicSilver.withOpacity(0.5),
              width: 1.5,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : sonicSilver,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }
  // Widget cho nút Social (Chỉ có Google - Placeholder, không dùng ảnh asset)
  Widget _buildSocialButton(String label, IconData icon, Color iconColor) {
    return Expanded(
      child: OutlinedButton.icon( // Changed to OutlinedButton to match LoginScreen
        onPressed: () { /* TODO: Implement Google Sign-Up */ ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Chức năng đăng ký bằng $label chưa được triển khai.'), backgroundColor: sonicSilver)); },
        icon: Icon(icon, color: iconColor, size: 24), // Use Icon directly
        label: Text(label, style: const TextStyle(color: Colors.white, fontSize: 15)),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 50),
          side: const BorderSide(color: darkSurface, width: 1.5),
          backgroundColor: Colors.black, // Match LoginScreen
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 12),
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
              // Nút Back (Giữ nguyên)
              Align( /* ... Back button ... */ ),
              const SizedBox(height: 20),

              // Tiêu đề (Giữ nguyên)
              const Text('Tạo tài khoản', style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 8),
              Text('Nhập thông tin cá nhân của bạn', style: TextStyle(fontSize: 16, color: sonicSilver.withOpacity(0.8))),
              const SizedBox(height: 30),

              // 1. INPUT TOGGLE (Email / Phone) (Giữ nguyên)
              Row( /* ... Toggle Buttons ... */ ),
              const SizedBox(height: 25),

              // 2. INPUT FIELDS (Thêm Confirm Password) (Giữ nguyên)
              TextField( controller: _emailOrPhoneController, /* ... email/phone input ... */ ),
              const SizedBox(height: 16),
              TextField( controller: _passwordController, /* ... password input ... */ ),
              const SizedBox(height: 16),
              TextField( controller: _confirmPasswordController, /* ... confirm password input ... */ ),
              const SizedBox(height: 12),

              // Lỗi hiển thị (Giữ nguyên)
// ...
              // Lỗi hiển thị
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0, bottom: 8.0), // Sửa lỗi: Thêm padding
                  child: Text( // Sửa lỗi: Thêm child
                    _errorMessage!,
                    style: const TextStyle(color: coralRed, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),

              // 3. NÚT ĐĂNG KÝ CHÍNH (Giữ nguyên)
// ...
              // 3. NÚT ĐĂNG KÝ CHÍNH (Giữ nguyên)
// ...
              // 3. NÚT ĐĂNG KÝ CHÍNH
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0), // Sửa lỗi: Thêm padding
                child: _isLoading // Sửa lỗi: Thêm child (kiểm tra loading)
                    ? const Center(child: CircularProgressIndicator(color: topazColor))
                    : ElevatedButton(
                  onPressed: _performRegistration,
                  child: const Text('Đăng ký', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 25),
// ...              const SizedBox(height: 25),

              // Phân cách "Hoặc đăng ký với" (Giữ nguyên)
              Row( /* ... Divider ... */ ),
              const SizedBox(height: 20),

              // 4. NÚT SOCIAL (Google Placeholder - đã cập nhật)
              Row(
                children: [
                  _buildSocialButton('Google', Icons.g_mobiledata_outlined, Colors.white), // Use Icon
                ],
              ),
              const SizedBox(height: 30),

              // 5. PRIVACY POLICY TEXT (Giữ nguyên)
              // Center( /* ... Privacy Policy text ... */ ), // You can keep or remove this
              // const SizedBox(height: 15),

              // 6. LIÊN KẾT ĐĂNG NHẬP (Giữ nguyên)
              Row( /* ... Link to Login Screen ... */ ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
