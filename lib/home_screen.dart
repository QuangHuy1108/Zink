// lib/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'session_manager.dart';
import 'login_screen.dart';
import 'add_post_screen.dart'; // <--- THÊM DÒNG NÀY

// Import các màn hình con, ẩn đi các class trùng lặp/giả định
// 1. FeedScreen: Định nghĩa chính thức FeedScreen
import 'feed_screen.dart';

// 2. ProfileScreen: Định nghĩa chính thức ProfileScreen. Ẩn FeedScreen giả định.
import 'profile_screen.dart' hide PostCard, Comment, PlaceholderScreen, FeedScreen, FollowersScreen, MessageScreen;

// 3. CreatePostScreen: Không xung đột
import 'create_post_screen.dart';

// 4. ReelsScreen: Ẩn ProfileScreen giả định và các class trùng lặp khác.
import 'reels_screen.dart' hide ShareSheetContent, ProfileScreen, ReelCommentSheetContent, Comment;

// 5. FriendsListScreen: Ẩn ProfileScreen giả định
import 'friends_list_screen.dart' hide ProfileScreen;


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0; // Tab đang được chọn
  bool _isBottomBarVisible = true; // Trạng thái hiển thị của thanh điều hướng

  static const double _bottomBarHeight = 60.0;
  static const double _syncOffset = 150.0;

  late List<Widget> _widgetOptions;

  static const Color topazColor = Color(0xFFF6C886);
  static const Color sonicSilver = Color(0xFF747579);
  static const Color surfaceColor = Colors.black;

  @override
  void initState() {
    super.initState();
    _widgetOptions = _initializeWidgetOptions();
  }

  void _navigateToHomeTab() {
    if (_selectedIndex != 0) {
      setState(() { _selectedIndex = 0; });
    }
  }

  void _performLogout(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
      await SessionManager().logoutUser();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
              (Route<dynamic> route) => false,
        );
      }
    } catch (e) { print("Lỗi đăng xuất: $e"); }
  }

  // KHÔI PHỤC _initializeWidgetOptions
  List<Widget> _initializeWidgetOptions() {
    return <Widget>[
      // Index 0: Trang chủ (FeedScreen)
      const FeedScreen(),
      // Index 1: Danh sách bạn bè (FriendsListScreen)
      FriendsListScreen(onNavigateToHome: _navigateToHomeTab),
      // Index 2: Placeholder cho FAB (Đăng bài/Status)
      const SizedBox.shrink(),
      // Index 3: ReelsScreen
      ReelsScreen(onNavigateToHome: _navigateToHomeTab),
      // Index 4: ProfileScreen
      ProfileScreen(
        onNavigateToHome: _navigateToHomeTab,
        onLogout: () => _performLogout(context),
        targetUserId: null,
      ),
    ];
  }

  void _onItemTapped(int index) {
    if (index == 2) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => AddPostScreen(onPostUploaded: () {})), // SỬA Ở ĐÂY: Bỏ `const`
      );
    } else {
      if (_selectedIndex != index) {
        setState(() {
          _selectedIndex = index;
          if (index != 0 && !_isBottomBarVisible) {
            _isBottomBarVisible = true;
          }
        });
      }
    }
  }

  Widget _buildStaticFab() {
    return FloatingActionButton(
      onPressed: () => _onItemTapped(2),
      backgroundColor: topazColor,
      foregroundColor: Colors.black,
      shape: const CircleBorder(),
      elevation: 4,
      child: const Icon(Icons.add_rounded, size: 24),
    );
  }

  Widget _buildAnimatedFabContainer(BuildContext context) {
    final double fabOffset = _isBottomBarVisible ? 0.0 : _syncOffset;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      transform: Matrix4.translationValues(0.0, fabOffset, 0.0),
      child: _buildStaticFab(),
    );
  }

  Widget _buildNavItem({required IconData icon, required int index}) {
    final bool isSelected = _selectedIndex == index;
    final Color color = isSelected ? topazColor : sonicSilver;

    return IconButton(
      icon: Icon(icon, size: 28, color: color),
      onPressed: () => _onItemTapped(index),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      splashRadius: 24,
    );
  }

  Widget _buildBottomAppBarContent(int selectedIndex, double height) {
    return BottomAppBar(
      color: surfaceColor,
      surfaceTintColor: surfaceColor,
      elevation: 0,
      notchMargin: 6.0,
      height: height,
      shape: const CircularNotchedRectangle(),
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            _buildNavItem(icon: Icons.home_rounded, index: 0),
            _buildNavItem(icon: Icons.group_rounded, index: 1),
            const SizedBox(width: 40),
            _buildNavItem(icon: Icons.slow_motion_video_rounded, index: 3),
            _buildNavItem(icon: Icons.person_rounded, index: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedBottomNavContainer(BuildContext context) {
    final double navOffset = _isBottomBarVisible ? 0.0 : _bottomBarHeight + MediaQuery.of(context).padding.bottom;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      transform: Matrix4.translationValues(0.0, navOffset, 0.0),
      child: _buildBottomAppBarContent(_selectedIndex, _bottomBarHeight),
    );
  }


  @override
  Widget build(BuildContext context) {
    if (_selectedIndex == 0) {
      return NotificationListener<UserScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.axis == Axis.vertical) {
            if (notification.direction == ScrollDirection.forward) {
              if (!_isBottomBarVisible) {
                setState(() { _isBottomBarVisible = true; });
              }
            }
            else if (notification.direction == ScrollDirection.reverse) {
              if (_isBottomBarVisible && notification.metrics.pixels > 50) {
                setState(() { _isBottomBarVisible = false; });
              }
            }
          }
          return false;
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          extendBody: true,
          body: IndexedStack(
            index: _selectedIndex,
            children: _widgetOptions,
          ),
          floatingActionButton: _buildAnimatedFabContainer(context),
          floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
          bottomNavigationBar: _buildAnimatedBottomNavContainer(context),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: IndexedStack(
        index: _selectedIndex,
        children: _widgetOptions,
      ),
      floatingActionButton: _buildStaticFab(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _buildBottomAppBarContent(_selectedIndex, _bottomBarHeight),
    );
  }
}
