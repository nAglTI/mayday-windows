import 'relay_target.dart';
import 'server_target.dart';
import 'split_tunnel_mode.dart';
import 'metrics_config.dart';
import 'network_rescue_config.dart';
import 'transport_config.dart';

class ClientProfile {
  const ClientProfile({
    this.relays = const [],
    this.userId = '',
    this.servers = const [],
    this.tunName = 'VPN0',
    this.dnsServers = const ['1.1.1.1'],
    this.transport = const TransportConfig(),
    this.networkRescue = const NetworkRescueConfig(),
    this.metrics = const MetricsConfig(),
    this.serverFailbackDelaySec = 60,
    this.prestartFullProbe = false,
    this.steadyStateQuickProbeEnabled = false,
    this.steadyStateBenchmarkEnabled = false,
    this.disableIpv6 = false,
    this.tunnelMtu = 1280,
    this.packetFragmentPayloadBytes = 0,
    this.disablePacketBatching = false,
    this.splitTunnelMode = SplitTunnelMode.disabled,
    this.windowsApps = const [],
    this.androidApps = const [],
    this.splitTunnelExtraFields = const {},
    this.extraFields = const {},
  });

  final List<RelayTarget> relays;
  final String userId;
  final List<ServerTarget> servers;
  final String tunName;
  final List<String> dnsServers;
  final TransportConfig transport;
  final NetworkRescueConfig networkRescue;
  final MetricsConfig metrics;
  final int serverFailbackDelaySec;
  final bool prestartFullProbe;
  final bool steadyStateQuickProbeEnabled;
  final bool steadyStateBenchmarkEnabled;
  final bool disableIpv6;
  final int tunnelMtu;
  final int packetFragmentPayloadBytes;
  final bool disablePacketBatching;
  final SplitTunnelMode splitTunnelMode;
  final List<String> windowsApps;
  final List<String> androidApps;
  final Map<String, Object?> splitTunnelExtraFields;
  final Map<String, Object?> extraFields;

  ClientProfile copyWith({
    List<RelayTarget>? relays,
    String? userId,
    List<ServerTarget>? servers,
    String? tunName,
    List<String>? dnsServers,
    TransportConfig? transport,
    NetworkRescueConfig? networkRescue,
    MetricsConfig? metrics,
    int? serverFailbackDelaySec,
    bool? prestartFullProbe,
    bool? steadyStateQuickProbeEnabled,
    bool? steadyStateBenchmarkEnabled,
    bool? disableIpv6,
    int? tunnelMtu,
    int? packetFragmentPayloadBytes,
    bool? disablePacketBatching,
    SplitTunnelMode? splitTunnelMode,
    List<String>? windowsApps,
    List<String>? androidApps,
    Map<String, Object?>? splitTunnelExtraFields,
    Map<String, Object?>? extraFields,
  }) {
    return ClientProfile(
      relays: relays ?? this.relays,
      userId: userId ?? this.userId,
      servers: servers ?? this.servers,
      tunName: tunName ?? this.tunName,
      dnsServers: dnsServers ?? this.dnsServers,
      transport: transport ?? this.transport,
      networkRescue: networkRescue ?? this.networkRescue,
      metrics: metrics ?? this.metrics,
      serverFailbackDelaySec:
          serverFailbackDelaySec ?? this.serverFailbackDelaySec,
      prestartFullProbe: prestartFullProbe ?? this.prestartFullProbe,
      steadyStateQuickProbeEnabled:
          steadyStateQuickProbeEnabled ?? this.steadyStateQuickProbeEnabled,
      steadyStateBenchmarkEnabled:
          steadyStateBenchmarkEnabled ?? this.steadyStateBenchmarkEnabled,
      disableIpv6: disableIpv6 ?? this.disableIpv6,
      tunnelMtu: tunnelMtu ?? this.tunnelMtu,
      packetFragmentPayloadBytes:
          packetFragmentPayloadBytes ?? this.packetFragmentPayloadBytes,
      disablePacketBatching:
          disablePacketBatching ?? this.disablePacketBatching,
      splitTunnelMode: splitTunnelMode ?? this.splitTunnelMode,
      windowsApps: windowsApps ?? this.windowsApps,
      androidApps: androidApps ?? this.androidApps,
      splitTunnelExtraFields:
          splitTunnelExtraFields ?? this.splitTunnelExtraFields,
      extraFields: extraFields ?? this.extraFields,
    );
  }
}
