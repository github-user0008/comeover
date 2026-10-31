import 'package:comeover/core/config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('inviteCodeFromUri', () {
    test('reads the custom scheme', () {
      expect(AppConfig.inviteCodeFromUri(Uri.parse('comeover://join/abc123')), 'ABC123');
    });

    test('reads an invite landing page', () {
      expect(AppConfig.inviteCodeFromUri(Uri.parse('https://relay.example/j/abc123')), 'ABC123');
      expect(AppConfig.inviteCodeFromUri(Uri.parse('http://localhost:8787/j/ABC123?x=1')), 'ABC123');
    });

    test('reads query and web hash links', () {
      expect(AppConfig.inviteCodeFromUri(Uri.parse('https://relay.example/?code=abc123')), 'ABC123');
      expect(AppConfig.inviteCodeFromUri(Uri.parse('https://relay.example/?invite=abc123')), 'ABC123');
      expect(AppConfig.inviteCodeFromUri(Uri.parse('https://relay.example/#join/abc123')), 'ABC123');
    });

    test('ignores unrelated links', () {
      expect(AppConfig.inviteCodeFromUri(Uri.parse('https://relay.example/about')), isNull);
      expect(AppConfig.inviteCodeFromUri(Uri.parse('comeover://join/')), isNull);
      expect(AppConfig.inviteCodeFromUri(Uri.parse('https://relay.example/?code=nope!')), isNull);
    });
  });
}
