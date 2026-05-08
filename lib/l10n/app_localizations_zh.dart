// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appName => '指针';

  @override
  String get compassTitle => '指针';

  @override
  String distanceUnit_m(Object distance) {
    return '${distance}m';
  }

  @override
  String distanceUnit_km(Object distance) {
    return '$distance km';
  }

  @override
  String get inviteCodeLabel => '我的邀请码';

  @override
  String get inviteCodeRefreshDaily => '每天自动刷新';

  @override
  String get inviteCodeRefreshOnDemand => '手动刷新';

  @override
  String get connectInputHint => '输入对方邀请码';

  @override
  String get connectWaiting => '等待对方同意…';

  @override
  String get connectApprove => '同意';

  @override
  String get connectReject => '拒绝';

  @override
  String connectRequestTitle(Object name) {
    return '$name 请求连接';
  }

  @override
  String get connectRequestBody => '是否允许与该设备共享位置？';

  @override
  String get peerOnline => '已上线';

  @override
  String get peerOffline => '对方当前离线';

  @override
  String get settingsTitle => '设置';

  @override
  String get settingsSectionInvite => '我的邀请码';

  @override
  String get settingsSectionDevices => '已配对设备';

  @override
  String get settingsSectionBackground => '后台与定位';

  @override
  String get settingsSectionWidget => '桌面组件';

  @override
  String get backgroundRunning => '后台运行';

  @override
  String get locationAccuracyHigh => '高精度';

  @override
  String get locationAccuracySaving => '省电模式';

  @override
  String get permissionDeniedTitle => '需要位置权限';

  @override
  String get permissionDeniedBody => '指针需要访问您的位置来计算方向和距离';

  @override
  String get permissionGoToSettings => '前往授权';

  @override
  String get noTargetSelected => '选择一个目标地点开始导航';

  @override
  String get addLocation => '添加地点';

  @override
  String get locationNameHint => '给这个地点起个名字';

  @override
  String get saveLocation => '保存';

  @override
  String get deleteConnection => '移除配对';

  @override
  String get retry => '重试';

  @override
  String get gpsUnavailable => 'GPS 不可用或精度不足';

  @override
  String get compassUnavailable => '设备不支持罗盘功能';

  @override
  String get inviteCodeExpired => '邀请码已过期';

  @override
  String get inviteCodeInvalid => '邀请码无效';

  @override
  String get connectionTimeout => '连接超时，请重试';

  @override
  String get peerRejected => '对方拒绝连接';

  @override
  String get webSocketDisconnected => '连接已断开，请检查网络';

  @override
  String get unknownError => '发生未知错误，请稍后重试';
}
