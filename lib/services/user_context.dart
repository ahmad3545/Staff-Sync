import 'package:fyp/services/auth_service.dart';

class UserContext {
  UserContext({AuthService? authService})
    : _authService = authService ?? AuthService();

  final AuthService _authService;

  String? get userId => _authService.currentUserId;

  bool get isAdmin {
    final email = _authService.currentUser?.email?.toLowerCase() ?? '';
    return email.contains('admin');
  }
}
