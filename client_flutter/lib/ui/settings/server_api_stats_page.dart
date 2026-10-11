import 'package:note123/filesync/http_api.dart';
import 'package:note123/ui/common/platform_app_bar.dart';
import 'package:note123/config/language_manager.dart';
import 'package:note123/utils/utils.dart';
import 'package:note123/config/app_config.dart';
import 'package:flutter/material.dart';

class ServerApiStatsPage extends StatefulWidget {
  const ServerApiStatsPage({super.key});

  @override
  State<ServerApiStatsPage> createState() => _ServerApiStatsPageState();
}

class _ServerApiStatsPageState extends State<ServerApiStatsPage> {
  late Future<List<APIStat>> _futureStats;

  @override
  void initState() {
    super.initState();
    _futureStats = _loadStats();
  }

  Future<List<APIStat>> _loadStats() async {
    final result = await HttpApi.fetchAPIStats();
    if (result.isSuccess() && result.data != null) {
      return result.data!;
    } else {
      throw Exception(result.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: createPlatformAppBar(title: l10n.apiCallStats),
      body: FutureBuilder<List<APIStat>>(
        future: _futureStats,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('${l10n.loadFailed}: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text(l10n.noData));
          }
          final stats = snapshot.data!;
          return ListView.separated(
            itemCount: stats.length,
            separatorBuilder: (_, __) => AppConfig.listViewDivider(context),
            itemBuilder: (context, index) {
              final stat = stats[index];
              return ListTile(
                title: Text(stat.apiName),
                subtitle: Text('${l10n.callCount}: ${stat.count}'),
                trailing: Text(Utils.formatTime(stat.lastCallTime)),
              );
            },
          );
        },
      ),
    );
  }
}
