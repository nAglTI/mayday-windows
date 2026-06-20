import 'package:flutter_test/flutter_test.dart';
import 'package:mayday_windows/core/models/runtime_status_snapshot.dart';

void main() {
  test('parses active route and telemetry from runtime status JSON', () {
    final snapshot = RuntimeStatusSnapshot.tryParse('''
{
  "state": "vpn_connected",
  "vpn_state": "active",
  "active_relay_id": "relay-eu-1",
  "active_transport": "https-rest",
  "active_server_id": "exit-main",
  "protocols": [
    {"id": "bt-utp", "rtt_ms": 92},
    {"id": "https-rest", "active": true, "rtt_ms": 41, "bps": 1500000}
  ],
  "endpoints": [
    {"relay_id": "relay-eu-1", "transport": "https-rest", "rank": 1, "score": 0.91, "download_bps": 2400000},
    {"relay_id": "relay-eu-2", "transport": "ws", "rank": 2}
  ],
  "upload_bps": 1200000
}
''');

    expect(snapshot, isNotNull);
    expect(snapshot!.coreState, 'vpn_connected');
    expect(snapshot.vpnState, 'active');
    expect(snapshot.activeRelayId, 'relay-eu-1');
    expect(snapshot.activeTransportId, 'https-rest');
    expect(snapshot.activeServerId, 'exit-main');
    expect(snapshot.uploadBps, 1200000);
    expect(snapshot.downloadBps, 2400000);
    expect(snapshot.aggregateBps, 3600000);
    expect(snapshot.protocolDiagnostics.first, contains('https-rest'));
    expect(snapshot.protocolDiagnostics.first, contains('active'));
    expect(snapshot.endpointDiagnostics.first, contains('current'));
    expect(snapshot.endpointDiagnostics.first, contains('relay-eu-1'));
  });

  test('extracts JSON payload from helper output noise', () {
    final snapshot = RuntimeStatusSnapshot.tryParse(
        'prefix {"active_transport":"ws"} suffix');

    expect(snapshot, isNotNull);
    expect(snapshot!.activeTransportId, 'ws');
  });

  test('parses line based status report from Windows pipe helper', () {
    final snapshot = RuntimeStatusSnapshot.tryParse('''
2026-06-20T20:31:41+03:00 state=vpn_connect vpn=active relay=r37 transport=bt-utp exit=g1 probed=0 best=- active_score=1900 active_rtt=0ms up=- down=-
  proto=bt-utp priority=10 known_relays=1 measured_relays=0 reachable_relays=1 best_relay=r37 rtt=- connect=- throughput=- quick=- up=- down=- active=yes reachable=yes
  proto=ws priority=15 known_relays=1 measured_relays=0 reachable_relays=0 best_relay=r37 rtt=- connect=- throughput=- quick=- up=- down=- reachable=no
  endpoint=r37-bt-utp relay=r37 proto=bt-utp priority=10 measured=no reachable=yes selected=yes active=yes score=1900 rtt=- connect=- throughput=- quick=- up=- down=- exits=g1,n1,u1
  endpoint=r37-ws relay=r37 proto=ws priority=15 measured=no reachable=no selected=no active=no score=850 rtt=- connect=- throughput=- quick=- up=- down=- exits=g1,n1,u1
''');

    expect(snapshot, isNotNull);
    expect(snapshot!.coreState, 'vpn_connect');
    expect(snapshot.vpnState, 'active');
    expect(snapshot.activeRelayId, 'r37');
    expect(snapshot.activeTransportId, 'bt-utp');
    expect(snapshot.activeServerId, 'g1');
    expect(snapshot.protocolDiagnostics.first, contains('bt-utp'));
    expect(snapshot.protocolDiagnostics.first, contains('active'));
    expect(snapshot.endpointDiagnostics.first, contains('current'));
    expect(snapshot.endpointDiagnostics.first, contains('relay r37'));
  });
}
