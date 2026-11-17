import 'package:get/get.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import '../modules/login/models/login_profile.dart';
import '../modules/media_detail/models/media_detail_cache.dart';
import '../modules/agent/models/agent_cache_models.dart';
import '../modules/plugin/models/installed_plugin_model_cache.dart';
import '../modules/plugin/models/plugin_model_cache.dart';
import '../modules/plugin/models/plugin_palette_cache_entry.dart';
import '../modules/search/models/search_history.dart';
import '../modules/site/models/site_icon_cache.dart';
import '../modules/site/models/site_model_cache.dart';
import '../modules/site/models/site_userdata_cache.dart';

class HiveService extends GetxService {
  late final Box<LoginProfile> loginProfileBox;
  late final Box<MediaDetailCache> mediaDetailCacheBox;
  late final Box<PluginModelCache> pluginModelCacheBox;
  late final Box<InstalledPluginModelCache> installedPluginModelCacheBox;
  late final Box<PluginPaletteCacheEntry> pluginPaletteCacheBox;
  late final Box<SiteIconCache> siteIconCacheBox;
  late final Box<SiteModelCache> siteModelCacheBox;
  late final Box<SiteUserDataCache> siteUserDataCacheBox;
  late final Box<SearchHistoryEntry> searchHistoryBox;
  late final Box<AgentSessionCache> agentSessionCacheBox;
  late final Box<AgentMessagesCacheEntry> agentMessagesCacheBox;
  late final Box<String> agentMetaCacheBox;

  Future<HiveService> init() async {
    await Hive.initFlutter();

    // Register adapters (only if not already registered)
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(LoginProfileAdapter());
      Hive.registerAdapter(MediaDetailCacheAdapter());
      Hive.registerAdapter(PluginModelCacheAdapter());
      Hive.registerAdapter(InstalledPluginModelCacheAdapter());
      Hive.registerAdapter(PluginPaletteCacheEntryAdapter());
      Hive.registerAdapter(SiteIconCacheAdapter());
      Hive.registerAdapter(SiteModelCacheAdapter());
      Hive.registerAdapter(SiteUserDataCacheAdapter());
      Hive.registerAdapter(SearchHistoryEntryAdapter());
      Hive.registerAdapter(AgentSessionCacheAdapter());
      Hive.registerAdapter(AgentChatMessageCacheAdapter());
      Hive.registerAdapter(AgentToolEventCacheAdapter());
      Hive.registerAdapter(AgentAttachmentCacheAdapter());
      Hive.registerAdapter(AgentMessagesCacheEntryAdapter());
    }

    // Open boxes concurrently
    final boxes = await Future.wait([
      Hive.openBox<LoginProfile>('loginProfiles'),
      Hive.openBox<MediaDetailCache>('mediaDetailCache'),
      Hive.openBox<PluginModelCache>('pluginModelCache'),
      Hive.openBox<InstalledPluginModelCache>('installedPluginModelCache'),
      Hive.openBox<PluginPaletteCacheEntry>('pluginPaletteCache'),
      Hive.openBox<SiteIconCache>('siteIconCache'),
      Hive.openBox<SiteModelCache>('siteModelCache'),
      Hive.openBox<SiteUserDataCache>('siteUserDataCache'),
      Hive.openBox<SearchHistoryEntry>('searchHistory'),
      Hive.openBox<AgentSessionCache>('agentSessionCache'),
      Hive.openBox<AgentMessagesCacheEntry>('agentMessagesCache'),
      Hive.openBox<String>('agentMetaCache'),
    ]);

    loginProfileBox = boxes[0] as Box<LoginProfile>;
    mediaDetailCacheBox = boxes[1] as Box<MediaDetailCache>;
    pluginModelCacheBox = boxes[2] as Box<PluginModelCache>;
    installedPluginModelCacheBox = boxes[3] as Box<InstalledPluginModelCache>;
    pluginPaletteCacheBox = boxes[4] as Box<PluginPaletteCacheEntry>;
    siteIconCacheBox = boxes[5] as Box<SiteIconCache>;
    siteModelCacheBox = boxes[6] as Box<SiteModelCache>;
    siteUserDataCacheBox = boxes[7] as Box<SiteUserDataCache>;
    searchHistoryBox = boxes[8] as Box<SearchHistoryEntry>;
    agentSessionCacheBox = boxes[9] as Box<AgentSessionCache>;
    agentMessagesCacheBox = boxes[10] as Box<AgentMessagesCacheEntry>;
    agentMetaCacheBox = boxes[11] as Box<String>;

    return this;
  }
}
