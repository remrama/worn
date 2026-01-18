import 'package:flutter/material.dart';
import '../models/device.dart';
import '../services/device_store.dart';
import '../services/log_service.dart';

class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  List<Device> _devices = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final devices = await DeviceStore.instance.getDevices();
    setState(() {
      _devices = devices;
      _loading = false;
    });
  }

  Future<void> _addDevice() async {
    final result = await showDialog<Device>(
      context: context,
      builder: (ctx) => const DeviceDialog(),
    );
    if (result != null) {
      await DeviceStore.instance.addDevice(result);
      await LogService.instance.logDeviceAdded(result);
      _load();
    }
  }

  Future<void> _editDevice(Device device) async {
    final result = await showDialog<Device>(
      context: context,
      builder: (ctx) => DeviceDialog(device: device),
    );
    if (result != null) {
      await DeviceStore.instance.updateDevice(result);
      await LogService.instance.logDeviceEdited(device, result);
      _load();
    }
  }

  Future<void> _deleteDevice(Device device) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Device'),
        content: Text('Delete "${device.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm == true) {
      await DeviceStore.instance.deleteDevice(device.id);
      await LogService.instance.logDeviceDeleted(device);
      _load();
    }
  }

  Future<void> _cycleStatus(Device device) async {
    final oldStatus = device.status;
    final newStatus = DeviceStatus.values[(device.status.index + 1) % DeviceStatus.values.length];
    final updated = device.copyWith(status: newStatus);
    await DeviceStore.instance.updateDevice(updated);
    await LogService.instance.logStatusChanged(device, oldStatus, newStatus);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Devices')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _devices.isEmpty
              ? const Center(child: Text('No devices. Tap + to add one.'))
              : ListView.builder(
                  itemCount: _devices.length,
                  itemBuilder: (ctx, i) {
                    final d = _devices[i];
                    return ListTile(
                      title: Text(d.name),
                      subtitle: Text(
                        '${Device.placementLabel(d.placement)}${d.serialNumber != null ? " | SN: ${d.serialNumber}" : ""}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _statusChip(d),
                          IconButton(
                            icon: const Icon(Icons.edit, size: 20),
                            onPressed: () => _editDevice(d),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, size: 20),
                            onPressed: () => _deleteDevice(d),
                          ),
                        ],
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addDevice,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _statusChip(Device d) {
    Color color;
    switch (d.status) {
      case DeviceStatus.worn:
        color = Colors.green;
        break;
      case DeviceStatus.loose:
        color = Colors.grey;
        break;
      case DeviceStatus.charging:
        color = Colors.orange;
        break;
    }
    return GestureDetector(
      onTap: () => _cycleStatus(d),
      child: Chip(
        label: Text(Device.statusLabel(d.status), style: const TextStyle(fontSize: 12)),
        backgroundColor: color.withValues(alpha: 0.2),
        side: BorderSide(color: color),
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class DeviceDialog extends StatefulWidget {
  final Device? device;
  const DeviceDialog({super.key, this.device});

  @override
  State<DeviceDialog> createState() => _DeviceDialogState();
}

class _DeviceDialogState extends State<DeviceDialog> {
  final _nameController = TextEditingController();
  final _snController = TextEditingController();
  Placement _placement = Placement.leftWrist;

  @override
  void initState() {
    super.initState();
    if (widget.device != null) {
      _nameController.text = widget.device!.name;
      _snController.text = widget.device!.serialNumber ?? '';
      _placement = widget.device!.placement;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _snController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final sn = _snController.text.trim();
    final device = Device(
      id: widget.device?.id,
      name: name,
      placement: _placement,
      serialNumber: sn.isEmpty ? null : sn,
      status: widget.device?.status ?? DeviceStatus.loose,
    );
    Navigator.pop(context, device);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.device != null;
    return AlertDialog(
      title: Text(isEdit ? 'Edit Device' : 'Add Device'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name (required, unique)'),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<Placement>(
              initialValue: _placement,
              decoration: const InputDecoration(labelText: 'Placement'),
              items: Placement.values
                  .map((p) => DropdownMenuItem(value: p, child: Text(Device.placementLabel(p))))
                  .toList(),
              onChanged: (v) => setState(() => _placement = v!),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _snController,
              decoration: const InputDecoration(labelText: 'Serial Number (optional)'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(onPressed: _submit, child: Text(isEdit ? 'Save' : 'Add')),
      ],
    );
  }
}
