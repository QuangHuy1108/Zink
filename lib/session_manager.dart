// lib/session_manager.dart
import 'package:shared_preferences/shared_preferences.dart';

class SessionManager {
  // Key để lưu trạng thái đăng nhập trong SharedPreferences
  static const String _isLoggedInKey = 'isLoggedIn';

  // Hàm private để lấy instance SharedPreferences
  Future<SharedPreferences> _getPrefs() async {
    return await SharedPreferences.getInstance();
  }

  // 1. Kiểm tra trạng thái đăng nhập đã lưu
  // Trả về true nếu đã đăng nhập, false nếu chưa hoặc có lỗi
  Future<bool> isLoggedIn() async {
    try {
      final prefs = await _getPrefs();
      // Lấy giá trị boolean, nếu chưa có (null) thì trả về false
      return prefs.getBool(_isLoggedInKey) ?? false;
    } catch (e) {
      // Xử lý lỗi nếu không thể đọc SharedPreferences
      print("Lỗi đọc SharedPreferences: $e");
      return false; // Mặc định là chưa đăng nhập nếu có lỗi
    }
  }

  // 2. Tạo Session (lưu trạng thái đã đăng nhập)
  // Được gọi sau khi đăng nhập Firebase Auth thành công
  Future<void> createLoginSession() async {
    try {
      final prefs = await _getPrefs();
      // Lưu giá trị true vào key _isLoggedInKey
      await prefs.setBool(_isLoggedInKey, true);
    } catch (e) {
      // Xử lý lỗi nếu không thể ghi SharedPreferences
      print("Lỗi ghi SharedPreferences (createLoginSession): $e");
    }
  }

  // 3. Xóa Session (lưu trạng thái đã đăng xuất)
  // Được gọi khi người dùng thực hiện logout
  Future<void> logoutUser() async {
    try {
      final prefs = await _getPrefs();
      // Xóa key _isLoggedInKey (hoặc đặt thành false)
      await prefs.remove(_isLoggedInKey);
      // Hoặc: await prefs.setBool(_isLoggedInKey, false);

      // Cân nhắc có nên xóa tất cả dữ liệu SharedPreferences không:
      // await prefs.clear(); // Xóa tất cả nếu cần
    } catch (e) {
      // Xử lý lỗi nếu không thể ghi/xóa SharedPreferences
      print("Lỗi ghi/xóa SharedPreferences (logoutUser): $e");
    }
  }
}