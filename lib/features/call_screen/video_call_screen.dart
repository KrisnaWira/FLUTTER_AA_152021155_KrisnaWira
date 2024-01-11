import 'dart:async';

import 'package:agora_rtc_engine/rtc_engine.dart';
import 'package:agora_rtc_engine/rtc_local_view.dart' as RtcLocalView;
import 'package:agora_rtc_engine/rtc_remote_view.dart' as RtcRemoteView;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:full_chat_application/core/storage/shared_preferences.dart';
import 'package:full_chat_application/core/utils/app_utils.dart';
import 'package:full_chat_application/features/home_screen/view/home_screen.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../core/storage/firebase_helper/fireBaseHelper.dart';
import '../chat_screen/manager/chat_cubit.dart';

class VideoCallScreen extends StatefulWidget {
  const VideoCallScreen({Key? key}) : super(key: key);

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  bool _joined = false;
  int _remoteUid = 0;
  bool _switch = false;
  bool _isMuted = false;
  late RtcEngine engine;
  late Timer timer;
  late FToast fToast;

  // Init the app
  Future<void> initPlatformState(ctx) async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      await [Permission.microphone, Permission.camera].request();
    }
    FireBaseHelper().updateCallStatus(ctx, "true");
    // Create RTC client instance
    RtcEngineContext context = RtcEngineContext(APP_ID);
    engine = await RtcEngine.createWithContext(context);
    // Define event handling logic
    engine.setEventHandler(RtcEngineEventHandler(
        joinChannelSuccess: (String channel, int uid, int elapsed) {
      debugPrint('joinChannelSuccess $channel $uid');
      setState(() {
        _joined = true;
      });
    }, userJoined: (int uid, int elapsed) {
      debugPrint('userJoined $uid');
      setState(() {
        _remoteUid = uid;
      });
      timer.cancel();
    }, userOffline: (int uid, UserOfflineReason reason) {
      debugPrint('userOffline $uid');
      setState(() {
        _remoteUid = 0;
      });
    }));
    // Enable video
    await engine.enableVideo();
    // Join channel with channel name as 123
    await engine.joinChannel(Token, 'bego', null, 0);
  }

  void missedCall(String msg) {
    if (context.read<ChatCubit>().peerUserData["email"] == null) {
      context.read<ChatCubit>().notifyUser(
          "${context.read<ChatCubit>().getCurrentUser()!.displayName}",
          "${context.read<ChatCubit>().getCurrentUser()!.displayName} called you",
          getEmail(),
          context.read<ChatCubit>().getCurrentUser()!.email);
    } else {
      context.read<ChatCubit>().notifyUser(
          "${context.read<ChatCubit>().getCurrentUser()!.displayName}",
          "${context.read<ChatCubit>().getCurrentUser()!.displayName} called you",
          context.read<ChatCubit>().peerUserData["email"],
          context.read<ChatCubit>().getCurrentUser()!.email);
    }
    Navigator.pop(context);
    Fluttertoast.showToast(
        msg: msg,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.CENTER,
        timeInSecForIosWeb: 1,
        fontSize: 16.0);
  }

  void endCall(String msg) {
    if (context.read<ChatCubit>().peerUserData["email"] == null) {
      context.read<ChatCubit>().notifyUser(
          "${context.read<ChatCubit>().getCurrentUser()!.displayName}",
          "${context.read<ChatCubit>().getCurrentUser()!.displayName} called you",
          getEmail(),
          context.read<ChatCubit>().getCurrentUser()!.email);
    } else {
      context.read<ChatCubit>().notifyUser(
          "${context.read<ChatCubit>().getCurrentUser()!.displayName}",
          "${context.read<ChatCubit>().getCurrentUser()!.displayName} called you",
          context.read<ChatCubit>().peerUserData["email"],
          context.read<ChatCubit>().getCurrentUser()!.email);
    }
    Get.off(const HomeScreen());
    Fluttertoast.showToast(
        msg: msg,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.CENTER,
        timeInSecForIosWeb: 1,
        fontSize: 16.0);
    FireBaseHelper().updateCallStatus(context, "");
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  void initState() {
    initPlatformState(context);
    timer = Timer(const Duration(milliseconds: 40000), () {
      missedCall("user didn't answer");
    });
    if (context.read<ChatCubit>().peerUserData["userId"] == null) {
      FirebaseFirestore.instance
          .collection("users")
          .doc(getId())
          .snapshots()
          .listen((event) {
        if (event["chatWith"].toString() == "false") {
          Get.off(const HomeScreen());
          buildShowSnackBar(context, "user end the call");
        }
      });
    } else {
      FirebaseFirestore.instance
          .collection("users")
          .doc(context.read<ChatCubit>().peerUserData["userId"])
          .snapshots()
          .listen((event) {
        if (event["chatWith"].toString() == "false") {
          Get.off(const HomeScreen());
          buildShowSnackBar(context, "user end the call");
        }
      });
    }

    super.initState();
  }

  @override
  void dispose() {
    engine.leaveChannel();
    engine.destroy();
    timer.cancel();
    super.dispose();
  }

  // Build UI
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: Stack(
          children: [
            Center(
              child: _switch ? _renderRemoteVideo() : _renderLocalPreview(),
            ),
            Align(
              alignment: Alignment.topLeft,
              child: Container(
                width: 150,
                height: 300,
                color: Colors.blue,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _switch = !_switch;
                    });
                  },
                  child: Center(
                    child:
                        _switch ? _renderLocalPreview() : _renderRemoteVideo(),
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                  width: MediaQuery.of(context).size.width,
                  height: MediaQuery.of(context).size.height * .2,
                  color: Colors.transparent,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                          iconSize: 50,
                          onPressed: () {
                            FireBaseHelper().updateCallStatus(context, "false");
                            endCall("You end the call");
                          },
                          icon: const CircleAvatar(
                              radius: 40,
                              backgroundColor: Colors.red,
                              child: Icon(
                                Icons.call_end,
                                color: Colors.white,
                                size: 40,
                              ))),
                      IconButton(
                          iconSize: 50,
                          onPressed: () {
                            setState(() {
                              _isMuted = !_isMuted;
                            });
                            buildShowSnackBar(context,
                                _isMuted ? "Call Muted" : "Call Unmuted");
                            engine.muteLocalAudioStream(_isMuted);
                          },
                          icon: CircleAvatar(
                              radius: 40,
                              child: _isMuted
                                  ? const Icon(
                                      Icons.volume_off,
                                      color: Colors.white,
                                      size: 40,
                                    )
                                  : const Icon(
                                      Icons.volume_up,
                                      color: Colors.white,
                                      size: 40,
                                    ))),
                      IconButton(
                          iconSize: 50,
                          onPressed: () {
                            engine.switchCamera();
                          },
                          icon: const CircleAvatar(
                              radius: 40,
                              child: Icon(
                                Icons.switch_camera,
                                color: Colors.white,
                                size: 40,
                              ))),
                    ],
                  )),
            )
          ],
        ),
      ),
    );
  }

  // Local video rendering
  Widget _renderLocalPreview() {
    if (_joined && defaultTargetPlatform == TargetPlatform.android ||
        _joined && defaultTargetPlatform == TargetPlatform.iOS) {
      return const RtcLocalView.SurfaceView();
    }

    if (_joined && defaultTargetPlatform == TargetPlatform.windows ||
        _joined && defaultTargetPlatform == TargetPlatform.macOS) {
      return const RtcLocalView.TextureView();
    } else {
      return const Text(
        'Please join channel first',
        textAlign: TextAlign.center,
      );
    }
  }

  // Remote video rendering
  Widget _renderRemoteVideo() {
    if (_remoteUid != 0 && defaultTargetPlatform == TargetPlatform.android ||
        _remoteUid != 0 && defaultTargetPlatform == TargetPlatform.iOS) {
      return RtcRemoteView.SurfaceView(
        uid: _remoteUid,
        channelId: "bego",
      );
    }

    if (_remoteUid != 0 && defaultTargetPlatform == TargetPlatform.windows ||
        _remoteUid != 0 && defaultTargetPlatform == TargetPlatform.macOS) {
      return RtcRemoteView.TextureView(
        uid: _remoteUid,
        channelId: "bego",
      );
    } else {
      return const Text(
        'Please wait remote user join',
        textAlign: TextAlign.center,
      );
    }
  }
}
