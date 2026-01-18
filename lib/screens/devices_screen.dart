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

  Future<void> _changeLocation(Device device) async {
    final newLocation = await showDialog<DeviceLocation>(
      context: context,
      builder: (ctx) => LocationPickerDialog(currentLocation: device.location),
    );
    if (newLocation != null && newLocation != device.location) {
      final oldLocation = device.location;
      final updated = device.copyWith(location: newLocation);
      await DeviceStore.instance.updateDevice(updated);
      await LogService.instance.logLocationChanged(device, oldLocation, newLocation);
      _load();
    }
  }

  Future<void> _addNote() async {
    final note = await showDialog<String>(
      context: context,
      builder: (ctx) => const NoteDialog(),
    );
    if (note != null && note.trim().isNotEmpty) {
      await LogService.instance.logNote(note.trim());
    }
  }

  Future<void> _addDeviceNote(Device device) async {
    final note = await showDialog<String>(
      context: context,
      builder: (ctx) => NoteDialog(deviceName: device.name),
    );
    if (note != null && note.trim().isNotEmpty) {
      await LogService.instance.logNote(note.trim(), device: device);
    }
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
                      subtitle: d.serialNumber != null ? Text('SN: ${d.serialNumber}') : null,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _locationChip(d),
                          IconButton(
                            icon: const Icon(Icons.note_add, size: 20),
                            onPressed: () => _addDeviceNote(d),
                            tooltip: 'Add note',
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit, size: 20),
                            onPressed: () => _editDevice(d),
                            tooltip: 'Edit',
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, size: 20),
                            onPressed: () => _deleteDevice(d),
                            tooltip: 'Delete',
                          ),
                        ],
                      ),
                    );
                  },
                ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'note',
            onPressed: _addNote,
            child: const Icon(Icons.note_add),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'device',
            onPressed: _addDevice,
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }

  Widget _locationChip(Device d) {
    Color color;
    if (d.location == DeviceLocation.loose) {
      color = Colors.grey;
    } else if (d.location == DeviceLocation.charging) {
      color = Colors.orange;
    } else {
      color = Colors.green; // Worn on body
    }
    return GestureDetector(
      onTap: () => _changeLocation(d),
      child: Chip(
        label: Text(Device.locationLabel(d.location), style: const TextStyle(fontSize: 12)),
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

  @override
  void initState() {
    super.initState();
    if (widget.device != null) {
      _nameController.text = widget.device!.name;
      _snController.text = widget.device!.serialNumber ?? '';
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
      location: widget.device?.location ?? DeviceLocation.loose,
      serialNumber: sn.isEmpty ? null : sn,
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

class LocationPickerDialog extends StatelessWidget {
  final DeviceLocation currentLocation;
  const LocationPickerDialog({super.key, required this.currentLocation});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Set Location'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: DeviceLocation.values.length,
          itemBuilder: (ctx, i) {
            final loc = DeviceLocation.values[i];
            final isSelected = loc == currentLocation;
            return ListTile(
              title: Text(Device.locationLabel(loc)),
              leading: isSelected ? const Icon(Icons.check, color: Colors.green) : null,
              onTap: () => Navigator.pop(context, loc),
            );
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      ],
    );
  }
}

class NoteDialog extends StatefulWidget {
  final String? deviceName;
  const NoteDialog({super.key, this.deviceName});

  @override
  State<NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<NoteDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.pop(context, _controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.deviceName != null
        ? 'Note for ${widget.deviceName}'
        : 'Add Note';
    return AlertDialog(
      title: Text(title),
      content: TextField(
        controller: _controller,
        decoration: const InputDecoration(hintText: 'Enter your note...'),
        autofocus: true,
        maxLines: 3,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}
