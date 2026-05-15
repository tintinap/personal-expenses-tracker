import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _storage = FlutterSecureStorage();

final authStateProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});

class AuthState {
  final bool isAuthenticated;
  final bool isLoading;
  final String? error;

  const AuthState({
    this.isAuthenticated = false,
    this.isLoading = false,
    this.error,
  });

  AuthState copyWith({bool? isAuthenticated, bool? isLoading, String? error}) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState(isLoading: true)) {
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    try {
      final token = await _storage.read(key: 'jwt_access_token');
      // Ignore placeholder mock tokens from development
      final isValid = token != null &&
          token.isNotEmpty &&
          !token.startsWith('mock_');
      state = state.copyWith(isAuthenticated: isValid, isLoading: false);
    } catch (e) {
      state = state.copyWith(isAuthenticated: false, isLoading: false, error: e.toString());
    }
  }

  Future<void> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // TODO: Replace with actual Google Sign-In + backend token exchange
      await Future.delayed(const Duration(seconds: 1));
      state = state.copyWith(isLoading: false, error: 'Google Sign-In not yet configured');
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Google sign-in failed');
    }
  }

  Future<void> signInWithApple() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // TODO: Replace with actual Apple Sign-In + backend token exchange
      await Future.delayed(const Duration(seconds: 1));
      state = state.copyWith(isLoading: false, error: 'Apple Sign-In not yet configured');
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Apple sign-in failed');
    }
  }

  Future<void> signOut() async {
    state = state.copyWith(isLoading: true);
    await _storage.delete(key: 'jwt_access_token');
    await _storage.delete(key: 'jwt_refresh_token');
    state = const AuthState(isAuthenticated: false, isLoading: false);
  }
}
