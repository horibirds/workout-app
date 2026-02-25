import 'dart:async';
import 'dart:isolate';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../domain/metrics.dart';
import 'imu_processor.dart';

/// Isolateに送るメッセージ
sealed class _IsolateMsg {}

class _SampleMsg extends _IsolateMsg {
  final ImuSample sample;
  _SampleMsg(this.sample);
}

class _InitMsg extends _IsolateMsg {
  final SendPort replyPort;
  final double massKg;
  _InitMsg(this.replyPort, this.massKg);
}

class _ResetMsg extends _IsolateMsg {}

/// Isolateから受け取る結果
sealed class _IsolateResult {}

class _LiveStateResult extends _IsolateResult {
  final LiveRepState state;
  _LiveStateResult(this.state);
}

class _RepCompletedResult extends _IsolateResult {
  final RepMetrics metrics;
  _RepCompletedResult(this.metrics);
}

// -----------------------------------------------------------------------------
// Isolateのエントリポイント（top-level関数が必須）
// -----------------------------------------------------------------------------
void _imuIsolateEntry(SendPort mainSendPort) {
  final receivePort = ReceivePort();
  mainSendPort.send(receivePort.sendPort);

  ImuEngine? engine;

  receivePort.listen((message) {
    if (message is _InitMsg) {
      engine = ImuEngine(massKg: message.massKg);
      // replyPortを保存して以降のメッセージで使う
      _currentReplyPort = message.replyPort;
    } else if (message is _SampleMsg && engine != null) {
      final prevRepCount = engine!.completedReps.length;
      final liveState = engine!.process(message.sample);

      // 新しいレップが完了していたら送信
      if (engine!.completedReps.length > prevRepCount) {
        final newRep = engine!.completedReps.last;
        _currentReplyPort?.send(_RepCompletedResult(newRep));
      }

      _currentReplyPort?.send(_LiveStateResult(liveState));
    } else if (message is _ResetMsg && engine != null) {
      engine!.reset();
    }
  });
}

SendPort? _currentReplyPort;

// -----------------------------------------------------------------------------
// メインIsolate側のサービス
// -----------------------------------------------------------------------------
class ImuService {
  Isolate? _isolate;
  SendPort? _isolateSendPort;
  ReceivePort? _receivePort;
  StreamSubscription? _sensorSub;

  final StreamController<LiveRepState> _liveStateCtrl =
      StreamController.broadcast();
  final StreamController<RepMetrics> _repCompletedCtrl =
      StreamController.broadcast();

  Stream<LiveRepState> get liveState => _liveStateCtrl.stream;
  Stream<RepMetrics> get repCompleted => _repCompletedCtrl.stream;

  Future<void> start({required double massKg}) async {
    await stop();

    // Isolate起動
    _receivePort = ReceivePort();
    _isolate = await Isolate.spawn(_imuIsolateEntry, _receivePort!.sendPort);

    // Isolateからの最初のメッセージはIsolateのSendPort
    final completer = Completer<SendPort>();
    _receivePort!.listen((msg) {
      if (!completer.isCompleted && msg is SendPort) {
        completer.complete(msg);
      } else if (msg is _LiveStateResult) {
        _liveStateCtrl.add(msg.state);
      } else if (msg is _RepCompletedResult) {
        _repCompletedCtrl.add(msg.metrics);
      }
    });

    _isolateSendPort = await completer.future;

    // Initメッセージ送信
    _isolateSendPort!.send(_InitMsg(_receivePort!.sendPort, massKg));

    // センサー購読（100Hz = 10ms間隔）
    _sensorSub = userAccelerometerEventStream(
      samplingPeriod: const Duration(microseconds: 10000),
    ).listen(_onSensorEvent);
  }

  void _onSensorEvent(UserAccelerometerEvent event) {
    // sensors_plus v6+: event.timestamp はハードウェアタイムスタンプ
    // userAccelerometer = 重力除去済み加速度
    // iOSの座標系: デバイスを縦持ちにしたとき Y軸が上方向
    // バーをiPhoneで計測するとき、バーの長軸にiPhoneを置くと Z軸が鉛直
    // ここでは Y軸を鉛直方向として扱う（マウント方向は後で設定化）
    final axVertical = event.y; // バーが上下に動く方向

    final timestampUs = event.timestamp.microsecondsSinceEpoch;

    _isolateSendPort?.send(_SampleMsg(ImuSample(axVertical, timestampUs)));
  }

  Future<void> stop() async {
    await _sensorSub?.cancel();
    _sensorSub = null;
    _isolateSendPort = null;
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _receivePort?.close();
    _receivePort = null;
  }

  void reset() {
    _isolateSendPort?.send(_ResetMsg());
  }

  void dispose() {
    stop();
    _liveStateCtrl.close();
    _repCompletedCtrl.close();
  }
}

// -----------------------------------------------------------------------------
// Riverpod Providers
// -----------------------------------------------------------------------------
final imuServiceProvider = Provider<ImuService>((ref) {
  final service = ImuService();
  ref.onDispose(service.dispose);
  return service;
});

final liveStateProvider = StreamProvider<LiveRepState>((ref) {
  final service = ref.watch(imuServiceProvider);
  return service.liveState;
});

final repCompletedProvider = StreamProvider<RepMetrics>((ref) {
  final service = ref.watch(imuServiceProvider);
  return service.repCompleted;
});

/// セッション中の全レップ履歴
final repHistoryProvider =
    StateNotifierProvider<RepHistoryNotifier, List<RepMetrics>>((ref) {
  final notifier = RepHistoryNotifier();
  ref.listen(repCompletedProvider, (_, next) {
    next.whenData((rep) => notifier.add(rep));
  });
  return notifier;
});

class RepHistoryNotifier extends StateNotifier<List<RepMetrics>> {
  RepHistoryNotifier() : super([]);

  void add(RepMetrics rep) {
    state = [...state, rep];
  }

  void clear() {
    state = [];
  }
}
