// lib/services/chat/call_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../models/chat/call_status.dart';
import 'call_token_service.dart';

class CallService {
  static final CallService _instance = CallService._internal();
  factory CallService() => _instance;
  CallService._internal();

  RtcEngine? _engine;
  bool _joined = false;
  bool _isInitializing = false;
  final _tokenService = CallTokenService();
  String? _currentChannel;
  CallType? _lastType;

  RtcEngine? get engine => _engine;
  bool get isJoined => _joined;

  Future<void> initEngine(String appId) async {
    if (_isInitializing) return;
    if (_engine != null) return;

    _isInitializing = true;
    try {
      _engine = createAgoraRtcEngine();
      await _engine!.initialize(
        RtcEngineContext(
          appId: appId,
          channelProfile: ChannelProfileType.channelProfileCommunication,
        ),
      );

      await _engine!.enableAudio();
      await _engine!.setAudioProfile(
        profile: AudioProfileType.audioProfileMusicHighQuality,
        scenario: AudioScenarioType.audioScenarioGameStreaming,
      );
      // Toujours activer le module vidéo (on mute/unmute selon le type)
      await _engine!.enableVideo();
      await _engine!.setEnableSpeakerphone(true);
      await _engine!.enableLocalAudio(true);

      debugPrint('✅ Agora engine ready');
    } catch (e) {
      debugPrint('❌ Agora init error: $e');
      _engine = null;
      rethrow;
    } finally {
      _isInitializing = false;
    }
  }

  Future<void> join({
    required String channel,
    required CallType type,
    required int uid,
    required Function(int remoteUid) onUserJoined,
    required Function() onUserLeft,
    required Function(String error) onError,
  }) async {
    try {
      _currentChannel = channel;
      _lastType = type;

      // Permissions
      final mic = await Permission.microphone.request();
      if (!mic.isGranted) throw Exception('Microphone permission denied');

      if (type == CallType.video) {
        final cam = await Permission.camera.request();
        if (!cam.isGranted) throw Exception('Camera permission denied');
      }

      // Token
      final cred = await _tokenService.getToken(channel: channel, uid: uid);
      final token = cred['token']!;
      final appId = cred['appId']!;

      if (_engine == null) await initEngine(appId);
      if (_engine == null) throw Exception('Engine not initialized');

      // Event handlers
      _engine!.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (conn, elapsed) {
            debugPrint('✅ Joined channel ${conn.channelId}');
            _joined = true;
          },
          onUserJoined: (conn, remoteUid, elapsed) {
            debugPrint('👤 Remote joined: $remoteUid');
            onUserJoined(remoteUid);
          },
          onUserOffline: (conn, remoteUid, reason) {
            debugPrint('👤 Remote left: $remoteUid ($reason)');
            onUserLeft();
          },
          onError: (err, msg) {
            debugPrint('❌ Agora error: $err - $msg');
            onError('Agora error: $err - $msg');
          },
          onConnectionStateChanged: (conn, state, reason) {
            debugPrint('🔌 Connection: $state ($reason)');
            if (state == ConnectionStateType.connectionStateFailed) {
              onError('Connection failed: $reason');
            }
          },
          onTokenPrivilegeWillExpire: (conn, _) async {
            try {
              final newCred =
                  await _tokenService.getToken(channel: channel, uid: uid);
              await _engine!.renewToken(newCred['token']!);
            } catch (e) {
              debugPrint('Token renew failed: $e');
            }
          },
        ),
      );

      // ─── RESET MÉDIA selon le type (corrige vidéo→audio résiduel) ───
      if (type == CallType.video) {
        await _engine!.enableVideo();
        await _engine!.enableLocalVideo(true);
        await _engine!.muteLocalVideoStream(false);
        await _engine!.startPreview();
      } else {
        await _engine!.muteLocalVideoStream(true);
        await _engine!.enableLocalVideo(false);
        await _engine!.stopPreview();
        // On ne disableVideo() plus définitivement pour permettre un switch ultérieur
      }

      final options = ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        channelProfile: ChannelProfileType.channelProfileCommunication,
        autoSubscribeAudio: true,
        autoSubscribeVideo: type == CallType.video,
        publishCameraTrack: type == CallType.video,
        publishMicrophoneTrack: true,
      );

      await _engine!.joinChannel(
        token: token,
        channelId: channel,
        uid: uid,
        options: options,
      );

      debugPrint('📞 Joined as $type channel=$channel uid=$uid');
    } catch (e) {
      debugPrint('❌ CallService.join error: $e');
      _joined = false;
      onError(e.toString());
      rethrow;
    }
  }

  Future<void> leave() async {
    try {
      if (_engine != null) {
        await _engine!.stopPreview();
        if (_joined) await _engine!.leaveChannel();
      }
    } catch (e) {
      debugPrint('leave error: $e');
    } finally {
      _joined = false;
      _currentChannel = null;
      _lastType = null;
    }
  }

  Future<void> mute(bool muted) async {
    await _engine?.muteLocalAudioStream(muted);
    await _engine?.enableLocalAudio(!muted);
  }

  Future<void> videoOff(bool off) async {
    await _engine?.muteLocalVideoStream(off);
    await _engine?.enableLocalVideo(!off);
    if (off) {
      await _engine?.stopPreview();
    } else {
      await _engine?.enableVideo();
      await _engine?.startPreview();
    }
  }

  Future<void> switchCam() async => await _engine?.switchCamera();

  Future<void> speaker(bool enable) async =>
      await _engine?.setEnableSpeakerphone(enable);

  void dispose() {
    try {
      _engine?.release();
    } catch (_) {}
    _engine = null;
    _joined = false;
    _currentChannel = null;
    _lastType = null;
  }
}
