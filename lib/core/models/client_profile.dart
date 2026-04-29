import 'relay_target.dart';
import 'server_target.dart';
import 'split_tunnel_mode.dart';
import 'metrics_config.dart';
import 'transport_config.dart';

class ClientProfile {
  const ClientProfile({
    this.displayName = '',
    this.relays = const [],
    this.userId = '',
    this.servers = const [],
    this.tunName = 'VPN0',
    this.dnsServers = const ['1.1.1.1'],
    this.transport = const TransportConfig(),
    this.metrics = const MetricsConfig(),
    this.serverFailbackDelaySec = 60,
    this.splitTunnelMode = SplitTunnelMode.disabled,
    this.windowsApps = const [],
    this.androidApps = const [],
    this.splitTunnelExtraFields = const {},
    this.extraFields = const {},
  });

  final String displayName;
  final List<RelayTarget> relays;
  final String userId;
  final List<ServerTarget> servers;
  final String tunName;
  final List<String> dnsServers;
  final TransportConfig transport;
  final MetricsConfig metrics;
  final int serverFailbackDelaySec;
  final SplitTunnelMode splitTunnelMode;
  final List<String> windowsApps;
  final List<String> androidApps;
  final Map<String, Object?> splitTunnelExtraFields;
  final Map<String, Object?> extraFields;

  ClientProfile copyWith({
    String? displayName,
    List<RelayTarget>? relays,
    String? userId,
    List<ServerTarget>? servers,
    String? tunName,
    List<String>? dnsServers,
    TransportConfig? transport,
    MetricsConfig? metrics,
    int? serverFailbackDelaySec,
    SplitTunnelMode? splitTunnelMode,
    List<String>? windowsApps,
    List<String>? androidApps,
    Map<String, Object?>? splitTunnelExtraFields,
    Map<String, Object?>? extraFields,
  }) {
    return ClientProfile(
      displayName: displayName ?? this.displayName,
      relays: relays ?? this.relays,
      userId: userId ?? this.userId,
      servers: servers ?? this.servers,
      tunName: tunName ?? this.tunName,
      dnsServers: dnsServers ?? this.dnsServers,
      transport: transport ?? this.transport,
      metrics: metrics ?? this.metrics,
      serverFailbackDelaySec:
          serverFailbackDelaySec ?? this.serverFailbackDelaySec,
      splitTunnelMode: splitTunnelMode ?? this.splitTunnelMode,
      windowsApps: windowsApps ?? this.windowsApps,
      androidApps: androidApps ?? this.androidApps,
      splitTunnelExtraFields:
          splitTunnelExtraFields ?? this.splitTunnelExtraFields,
      extraFields: extraFields ?? this.extraFields,
    );
  }
}
