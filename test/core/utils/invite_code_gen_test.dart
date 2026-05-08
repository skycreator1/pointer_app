import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pointer_app/core/models/invite_code.dart';
import 'package:pointer_app/core/utils/invite_code_gen.dart';

void main() {
  test('daily 模式：同一天同一用户生成的码相同', () {
    fakeAsync((async) {
      final base = DateTime(2020, 1, 1, 8);
      DateTime now() => base.add(async.elapsed);

      final c1 = generateCode('u1', InviteCodeRefreshMode.daily, now: now);
      async.elapse(const Duration(hours: 2));
      final c2 = generateCode('u1', InviteCodeRefreshMode.daily, now: now);

      expect(c1, c2);
    });
  });

  test('daily 模式：不同天生成的码不同', () {
    fakeAsync((async) {
      final base = DateTime(2020, 1, 1, 8);
      DateTime now() => base.add(async.elapsed);

      final c1 = generateCode('u1', InviteCodeRefreshMode.daily, now: now);
      async.elapse(const Duration(days: 1));
      final c2 = generateCode('u1', InviteCodeRefreshMode.daily, now: now);

      expect(c1, isNot(c2));
    });
  });

  test('onDemand 模式：两次调用生成不同的码', () {
    fakeAsync((async) {
      final base = DateTime(2020, 1, 1, 8);
      DateTime now() => base.add(async.elapsed);

      final c1 = generateCode('u1', InviteCodeRefreshMode.onDemand, now: now);
      async.elapse(const Duration(milliseconds: 1));
      final c2 = generateCode('u1', InviteCodeRefreshMode.onDemand, now: now);

      expect(c1, isNot(c2));
    });
  });

  test('生成的码不含 0/O/1/I 且长度固定为8位', () {
    fakeAsync((async) {
      final base = DateTime(2020, 1, 1, 8);
      DateTime now() => base.add(async.elapsed);

      final code = generateCode('u1', InviteCodeRefreshMode.daily, now: now);

      expect(code.length, 8);
      expect(code.contains('0'), isFalse);
      expect(code.contains('O'), isFalse);
      expect(code.contains('1'), isFalse);
      expect(code.contains('I'), isFalse);
    });
  });
}
