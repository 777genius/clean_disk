import 'dart:io';

String defaultScanTargetPath() {
  final home = Platform.environment['HOME']?.trim();
  if (home != null && home.isNotEmpty) {
    return home;
  }

  final userProfile = Platform.environment['USERPROFILE']?.trim();
  if (userProfile != null && userProfile.isNotEmpty) {
    return userProfile;
  }

  final systemDrive = Platform.environment['SystemDrive']?.trim();
  if (systemDrive != null && systemDrive.isNotEmpty) {
    return systemDrive;
  }

  return '/';
}
