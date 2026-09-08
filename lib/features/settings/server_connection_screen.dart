import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flax/core/providers/server_provider.dart';
import 'package:flax/domain/models/server.dart';
import 'package:flax/services/network/network_target_resolver.dart';
import 'package:flax/shared/widgets/up_back_button.dart';

class ServerConnectionScreen extends ConsumerStatefulWidget {
  final String? serverId;

  const ServerConnectionScreen({super.key, this.serverId});

  @override
  ConsumerState<ServerConnectionScreen> createState() =>
      _ServerConnectionScreenState();
}

class _ServerConnectionScreenState
    extends ConsumerState<ServerConnectionScreen> {
  late TextEditingController _hostController;
  late TextEditingController _portController;
  late TextEditingController _newSsidController;

  bool _initialized = false;
  bool _testingConnection = false;
  bool _detectingWifi = false;
  String? _testResult;
  bool? _testSuccess;
  String? _currentWifiSsid;

  @override
  void initState() {
    super.initState();
    _hostController = TextEditingController();
    _portController = TextEditingController();
    _newSsidController = TextEditingController();
    _detectCurrentWifi();
  }

  Future<void> _detectCurrentWifi({bool requestPermission = false}) async {
    if (requestPermission) {
      setState(() => _detectingWifi = true);
    }
    try {
      final resolver = ref.read(networkTargetResolverProvider.notifier);
      if (requestPermission && Platform.isAndroid) {
        await resolver.requestLocationPermission();
      }
      final ssid = await resolver.getCurrentSsid();
      if (mounted) {
        setState(() {
          _currentWifiSsid = ssid;
        });
      }
    } finally {
      if (mounted && requestPermission) {
        setState(() => _detectingWifi = false);
      }
    }
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _newSsidController.dispose();
    super.dispose();
  }

  Server? _getServer(List<Server> servers) {
    if (widget.serverId != null) {
      try {
        return servers.firstWhere((s) => s.id == widget.serverId);
      } catch (_) {
        return null;
      }
    }
    try {
      return servers.firstWhere((s) => s.isActive);
    } catch (_) {
      return servers.isNotEmpty ? servers.first : null;
    }
  }

  void _initFields(Server server) {
    if (_initialized) return;
    final config = server.localNetworkConfig;
    _hostController.text = config.localHost;
    _portController.text = config.localPort.toString();
    _initialized = true;
  }

  void _saveConfig(Server server, LocalNetworkConfig newConfig) {
    final updatedServer = server.copyWith(localNetworkConfig: newConfig);
    ref.read(serverListProvider.notifier).updateServer(updatedServer);
    ref.read(networkTargetResolverProvider.notifier).evaluate();
  }

  void _updateHostAndPort(Server server) {
    final hostText = _hostController.text.trim();
    final portText = _portController.text.trim();
    final parsedPort = int.tryParse(portText) ?? 4533;

    final config = server.localNetworkConfig.copyWith(
      localHost: hostText,
      localPort: parsedPort,
    );
    _saveConfig(server, config);
  }

  Future<void> _testConnection(LocalNetworkConfig config) async {
    final host = _hostController.text.trim();
    final port = int.tryParse(_portController.text.trim()) ?? 4533;

    if (host.isEmpty) {
      setState(() {
        _testSuccess = false;
        _testResult = 'Please enter a valid IP address or hostname';
      });
      return;
    }

    final testConfig = config.copyWith(localHost: host, localPort: port);
    final url = testConfig.localBaseUrl;
    if (url == null) {
      setState(() {
        _testSuccess = false;
        _testResult = 'Invalid endpoint configuration';
      });
      return;
    }

    setState(() {
      _testingConnection = true;
      _testResult = null;
      _testSuccess = null;
    });

    final stopwatch = Stopwatch()..start();
    final ok = await NetworkTargetResolver.probeLocalEndpoint(
      url,
      server: _getServer(ref.read(serverListProvider)),
      trustSelfSigned: testConfig.trustSelfSignedCerts,
      timeout: Duration(milliseconds: testConfig.probeTimeoutMs),
    );
    stopwatch.stop();

    if (mounted) {
      setState(() {
        _testingConnection = false;
        _testSuccess = ok;
        _testResult = ok
            ? 'Connected successfully (${stopwatch.elapsedMilliseconds} ms)'
            : 'Unreachable at $url. Verify server IP, port, and Wi-Fi connection.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servers = ref.watch(serverListProvider);
    final server = _getServer(servers);

    if (server == null) {
      return Scaffold(
        appBar: AppBar(
          leading: const UpBackButton(fallbackLocation: '/settings'),
          title: const Text('Server Connection'),
        ),
        body: const Center(child: Text('No server found')),
      );
    }

    _initFields(server);
    final config = server.localNetworkConfig;
    final targetState = ref.watch(networkTargetResolverProvider);

    return Scaffold(
      appBar: AppBar(
        leading: const UpBackButton(fallbackLocation: '/settings'),
        title: const Text('Server Connection'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // ── Status Overview Card ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.5,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.5,
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          targetState.isUsingLocal
                              ? Icons.wifi
                              : Icons.cloud_outlined,
                          color: targetState.isUsingLocal
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            server.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: targetState.isUsingLocal
                                ? theme.colorScheme.primaryContainer
                                : theme.colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            targetState.isUsingLocal ? 'Local LAN' : 'Remote',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: targetState.isUsingLocal
                                  ? theme.colorScheme.onPrimaryContainer
                                  : theme.colorScheme.onSecondaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Active URL: ${targetState.effectiveBaseUrl.isNotEmpty ? targetState.effectiveBaseUrl : server.baseUrl}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    if (targetState.statusMessage != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        targetState.statusMessage!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: targetState.isUsingLocal
                              ? theme.colorScheme.primary
                              : theme.colorScheme.error,
                        ),
                      ),
                    ],
                    if (targetState.currentSsid != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Connected Wi-Fi: ${targetState.currentSsid}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // ── Local Network Target Section ──
          _SectionTitle(title: 'Local Network Target'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              'Route requests directly to your server on your home Wi-Fi network. Bypasses hairpin NAT, CGNAT, and bandwidth limits.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          SwitchListTile(
            title: const Text('Enable Local LAN Endpoint'),
            subtitle: const Text('Connect via local IP when on home Wi-Fi'),
            value: config.enabled,
            onChanged: (val) {
              _saveConfig(server, config.copyWith(enabled: val));
            },
          ),

          if (config.enabled) ...[
            const Divider(),
            _SectionTitle(title: 'Local Endpoint Settings'),

            // Protocol & Host & Port
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('HTTP')),
                      ButtonSegment(value: true, label: Text('HTTPS')),
                    ],
                    selected: {config.useHttps},
                    onSelectionChanged: (s) {
                      _saveConfig(server, config.copyWith(useHttps: s.first));
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _hostController,
                      decoration: const InputDecoration(
                        labelText: 'Local IP / Hostname',
                        hintText: '192.168.1.100',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (_) => _updateHostAndPort(server),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _portController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Port',
                        hintText: '4533',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (_) => _updateHostAndPort(server),
                    ),
                  ),
                ],
              ),
            ),
            if (config.localBaseUrl != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                child: Text(
                  'Resolved Local URL: ${config.localBaseUrl}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),

            if (config.useHttps)
              SwitchListTile(
                title: const Text('Trust Self-Signed Certificates'),
                subtitle: const Text(
                  'Allow HTTPS connections with private/homelab certificates',
                ),
                value: config.trustSelfSignedCerts,
                onChanged: (val) {
                  _saveConfig(
                    server,
                    config.copyWith(trustSelfSignedCerts: val),
                  );
                },
              ),

            // Live Connection Test
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: _testingConnection
                        ? null
                        : () => _testConnection(config),
                    icon: _testingConnection
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.network_ping),
                    label: const Text('Test Local Connection'),
                  ),
                  if (_testResult != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _testSuccess == true
                              ? Icons.check_circle
                              : Icons.error_outline,
                          size: 18,
                          color: _testSuccess == true
                              ? Colors.green
                              : theme.colorScheme.error,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            _testResult!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: _testSuccess == true
                                  ? Colors.green
                                  : theme.colorScheme.error,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),

            const Divider(),
            _SectionTitle(title: 'Target Wi-Fi Networks (SSIDs)'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                'Specify the Wi-Fi network names where this local IP is reachable. If empty, local target is automatically attempted on any Wi-Fi or Ethernet.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),

            // Current Wi-Fi quick-add and detect/refresh button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (_currentWifiSsid != null && _currentWifiSsid!.isNotEmpty)
                    ActionChip(
                      avatar: const Icon(Icons.add, size: 16),
                      label: Text('Add Current Wi-Fi: "$_currentWifiSsid"'),
                      onPressed: config.targetSsids.contains(_currentWifiSsid)
                          ? null
                          : () {
                              final updated = [
                                ...config.targetSsids,
                                _currentWifiSsid!,
                              ];
                              _saveConfig(
                                server,
                                config.copyWith(targetSsids: updated),
                              );
                            },
                    ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: _detectingWifi
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.wifi_find, size: 16),
                    label: Text(
                      _currentWifiSsid != null
                          ? 'Refresh Wi-Fi Name'
                          : 'Detect Current Wi-Fi',
                      style: const TextStyle(fontSize: 12),
                    ),
                    onPressed: _detectingWifi
                        ? null
                        : () => _detectCurrentWifi(requestPermission: true),
                  ),
                ],
              ),
            ),

            // Configured SSIDs chips
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: config.targetSsids.isEmpty
                  ? Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 18,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'No SSIDs configured. Direct local connection will be attempted on all Wi-Fi and Ethernet networks.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: config.targetSsids.map((ssid) {
                        return Chip(
                          label: Text(ssid),
                          deleteIcon: const Icon(Icons.close, size: 16),
                          onDeleted: () {
                            final updated = config.targetSsids
                                .where((s) => s != ssid)
                                .toList();
                            _saveConfig(
                              server,
                              config.copyWith(targetSsids: updated),
                            );
                          },
                        );
                      }).toList(),
                    ),
            ),

            // Add manual SSID input
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _newSsidController,
                      decoration: const InputDecoration(
                        labelText: 'Add Wi-Fi SSID manually',
                        hintText: 'e.g. MyHomeNetwork_5G',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onSubmitted: (val) {
                        final trimmed = val.trim();
                        if (trimmed.isNotEmpty &&
                            !config.targetSsids.contains(trimmed)) {
                          final updated = [...config.targetSsids, trimmed];
                          _saveConfig(
                            server,
                            config.copyWith(targetSsids: updated),
                          );
                          _newSsidController.clear();
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    icon: const Icon(Icons.add),
                    tooltip: 'Add SSID',
                    onPressed: () {
                      final trimmed = _newSsidController.text.trim();
                      if (trimmed.isNotEmpty &&
                          !config.targetSsids.contains(trimmed)) {
                        final updated = [...config.targetSsids, trimmed];
                        _saveConfig(
                          server,
                          config.copyWith(targetSsids: updated),
                        );
                        _newSsidController.clear();
                      }
                    },
                  ),
                ],
              ),
            ),

            const Divider(),
            _SectionTitle(title: 'Failover & Probing'),
            SwitchListTile(
              title: const Text('Automatic Failover to External URL'),
              subtitle: const Text(
                'If local endpoint is unreachable on matching Wi-Fi, seamlessly fallback to external server URL',
              ),
              value: config.fallbackToExternal,
              onChanged: (val) {
                _saveConfig(server, config.copyWith(fallbackToExternal: val));
              },
            ),
            ListTile(
              title: const Text('Probe Timeout'),
              subtitle: Text(
                'Maximum time to wait when verifying local endpoint: ${config.probeTimeoutMs} ms',
              ),
              trailing: DropdownButton<int>(
                value: config.probeTimeoutMs,
                underline: const SizedBox.shrink(),
                borderRadius: BorderRadius.circular(8),
                items: const [
                  DropdownMenuItem(value: 500, child: Text('500 ms')),
                  DropdownMenuItem(value: 1000, child: Text('1000 ms')),
                  DropdownMenuItem(value: 1500, child: Text('1500 ms')),
                  DropdownMenuItem(value: 2500, child: Text('2500 ms')),
                  DropdownMenuItem(value: 5000, child: Text('5000 ms')),
                ],
                onChanged: (ms) {
                  if (ms != null) {
                    _saveConfig(server, config.copyWith(probeTimeoutMs: ms));
                  }
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
