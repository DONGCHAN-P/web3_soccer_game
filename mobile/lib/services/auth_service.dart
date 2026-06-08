import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';

class AuthService {
  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) =>
      supabase.auth.signUp(email: email, password: password);

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) =>
      supabase.auth.signInWithPassword(email: email, password: password);

  Future<void> signOut() => supabase.auth.signOut();

  String? get currentUserId => supabase.auth.currentUser?.id;
}
