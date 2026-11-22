import 'package:flutter/material.dart';
import '../models/epg_programme.dart';
import '../core/platform/device_layout.dart';
import 'tv_epg_timeline.dart';
import 'mobile_epg_list.dart';

class ChannelEpgPanel extends StatelessWidget {
  const ChannelEpgPanel({super.key, required this.programmes});
  final List<EpgProgramme> programmes;
  @override Widget build(BuildContext context) => DeviceLayout.isTelevision
    ? TvEpgTimeline(programmes: programmes)
    : SizedBox(height: 190, child: MobileEpgList(programmes: programmes));
}
