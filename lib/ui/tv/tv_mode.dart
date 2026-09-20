import 'package:flutter/material.dart';

/// 遥控器（方向键）环境：Android TV、电视盒子等没有触摸屏、靠方向键操作。
///
/// Flutter 在方向键导航的设备上把 [NavigationMode] 报为
/// [NavigationMode.directional]，用它区分电视与手机/桌面，避免在手机上
/// 出现焦点框和电视专用布局。
bool isTvNavigation(BuildContext context) =>
    MediaQuery.navigationModeOf(context) == NavigationMode.directional;
