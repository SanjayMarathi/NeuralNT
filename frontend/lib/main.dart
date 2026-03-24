import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const NeuralNTApp());
}

class NeuralNTApp extends StatelessWidget {
  const NeuralNTApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NeuralNT',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
      ),
      home: const Dashboard(),
    );
  }
}

// ======================== Connection Service ========================
class ConnectionService {
  static final ConnectionService _instance = ConnectionService._internal();
  final Connectivity _connectivity = Connectivity();
  bool _isConnected = false;

  factory ConnectionService() {
    return _instance;
  }

  ConnectionService._internal();

  bool get isConnected => _isConnected;

  Future<void> init() async {
    try {
      // Windows doesn't support connectivity checks the same way
      if (Platform.isWindows) {
        _isConnected = true;
        return;
      }
      
      final result = await _connectivity.checkConnectivity();
      if (result is List) {
        _isConnected = (result as List).isNotEmpty;
      } else {
        _isConnected = result != ConnectivityResult.none;
      }
    } catch (e) {
      // Assume connected on error (will be verified by API check anyway)
      _isConnected = true;
    }
  }

  Stream<bool> get connectionStream {
    return _connectivity.onConnectivityChanged.map((result) {
      // Windows doesn't support connectivity streaming
      if (Platform.isWindows) {
        _isConnected = true;
      } else if (result is List) {
        _isConnected = (result as List).isNotEmpty;
      } else {
        _isConnected = result != ConnectivityResult.none;
      }
      return _isConnected;
    });
  }

  Future<bool> checkApiConnection(String baseUrl) async {
    try {
      final response = await http
          .get(Uri.parse("$baseUrl/health"))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}

// ======================== Dashboard Widget ========================
class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  int _selectedIndex = 0;
  String _architectureText = "";
  bool _isConnected = false;
  bool _apiAvailable = false;
  String _connectionStatus = "Checking...";

  final _lrController = TextEditingController(text: "0.001");
  final _batchController = TextEditingController(text: "32");
  final _sizeController = TextEditingController(text: "32");
  final _epochController = TextEditingController(text: "10");

  String _selectedLoss = "CrossEntropyLoss";
  String _selectedOptimizer = "Adam";
  int _selectedChannels = 3;
  PlatformFile? _selectedFile;
  bool _isTraining = false;
  String _trainingLogs = "";

  File? _predictionImage;
  String _predictionResult = "";
  bool _isPredicting = false;

  final TextEditingController _serverAddressController = TextEditingController();
  final TextEditingController _serverPortController = TextEditingController();
  String _serverAddress = "";
  String _serverPort = "";

  String get baseUrl => "http://$_serverAddress:$_serverPort";

  final ImagePicker _imagePicker = ImagePicker();
  final ConnectionService _connectionService = ConnectionService();


  @override
  void initState() {
    super.initState();
    // On physical Android device, default to empty (user must enter)
    // On emulator, use 10.0.2.2
    // On desktop, use localhost
    if (Platform.isAndroid) {
      _serverAddressController.text = "10.0.2.2";
      _serverPortController.text = "8000";
    } else {
      _serverAddressController.text = "localhost";
      _serverPortController.text = "8000";
    }
    _applyServerConfig();
    _checkConnectivity();
    _setupConnectionListener();
    _requestPermissions();
  }

  void _applyServerConfig() {
    setState(() {
      _serverAddress = _serverAddressController.text.trim();
      _serverPort = _serverPortController.text.trim();
      _connectionStatus = "Checking...";
      _checkApiConnection();
    });
  }

  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      await Permission.camera.request();
      await Permission.photos.request();
      await Permission.storage.request();
    }
  }

  void _setupConnectionListener() {
    _connectionService.connectionStream.listen((isConnected) {
      if (mounted) {
        setState(() {
          _isConnected = isConnected;
          _connectionStatus = isConnected ? "Connected" : "No Connection";
        });
        if (isConnected) {
          _checkApiConnection();
        }
      }
    });
  }

  Future<void> _checkConnectivity() async {
    await _connectionService.init();
    if (mounted) {
      setState(() {
        _isConnected = _connectionService.isConnected;
        _connectionStatus = _isConnected ? "Connected" : "No Connection";
      });
    }
    if (_isConnected) {
      _checkApiConnection();
    }
  }

  Future<void> _checkApiConnection() async {
    final available = await _connectionService.checkApiConnection(baseUrl);
    if (mounted) {
      setState(() {
        _apiAvailable = available;
        if (available) {
          _fetchArchitecture();
        }
      });
    }
  }

  Future<void> _fetchArchitecture() async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/architecture")).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200 && mounted) {
        setState(() {
          _architectureText = json.decode(response.body)['text'];
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error fetching architecture: $e")),
        );
      }
    }
  }

  Future<void> _addLayer(String type, String inDim, String outDim) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/add_layer"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "layer_type": type,
          "in_dim": inDim,
          "out_dim": outDim,
        }),
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        _fetchArchitecture();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${json.decode(response.body)['detail']}")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error adding layer: $e")),
        );
      }
    }
  }

  Future<void> _startTraining() async {
    if (_selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a dataset file first")),
      );
      return;
    }

    setState(() {
      _isTraining = true;
      _trainingLogs = "Uploading dataset...\n";
    });

    try {
      var request = http.MultipartRequest('POST', Uri.parse("$baseUrl/train"));
      request.fields['loss_name'] = _selectedLoss;
      request.fields['opt_name'] = _selectedOptimizer;
      request.fields['lr'] = _lrController.text;
      request.fields['batch_size'] = _batchController.text;
      request.fields['image_size'] = _sizeController.text;
      request.fields['epochs'] = _epochController.text;
      request.fields['num_channels'] = _selectedChannels.toString();

      request.files.add(await http.MultipartFile.fromPath(
        'dataset',
        _selectedFile!.path!,
      ));

      var streamedResponse = await request.send().timeout(const Duration(minutes: 30));
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 && mounted) {
        var data = json.decode(response.body);
        setState(() {
          _trainingLogs += "\n✓ Training completed successfully!\n";
          _trainingLogs += "Logs: ${data['logs']}\n";
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Training completed!")),
          );
        }
      } else if (mounted) {
        setState(() {
          _trainingLogs += "\n✗ Error: ${response.body}\n";
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _trainingLogs += "\n✗ Exception: $e\n";
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTraining = false;
        });
      }
    }
  }

  Future<void> _runPrediction() async {
    if (_predictionImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select an image first")),
      );
      return;
    }

    setState(() {
      _isPredicting = true;
      _predictionResult = "Running inference...";
    });

    try {
      var request = http.MultipartRequest('POST', Uri.parse("$baseUrl/predict"));
      request.fields['image_size'] = _sizeController.text;
      request.files.add(await http.MultipartFile.fromPath(
        'image',
        _predictionImage!.path,
      ));

      var streamedResponse = await request.send().timeout(const Duration(seconds: 30));
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 && mounted) {
        var data = json.decode(response.body);
        setState(() {
          _predictionResult =
              "✓ Prediction: ${data['prediction']}\nConfidence: ${data['confidence']}";
        });
      } else if (mounted) {
        setState(() {
          _predictionResult = "✗ Error: ${response.body}";
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _predictionResult = "✗ Exception: $e";
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPredicting = false;
        });
      }
    }
  }

  Future<void> _runCifarTest() async {
    setState(() => _predictionResult = "Running CIFAR test...");
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/cifar-test"),
        body: {
          "image_size": _sizeController.text,
          "batch_size": "8",
        },
      ).timeout(const Duration(seconds: 120));

      if (response.statusCode == 200 && mounted) {
        final data = json.decode(response.body);
        setState(() {
          _predictionResult =
            "CIFAR test complete: ${data['batch_accuracy']} (${data['correct']}/${data['total_tested']})\n"
            "Sample:\n" +
            (data['preview'] as List).map((item) => "${item['true']} → ${item['predicted']} ${(item['confidence']*100).toStringAsFixed(1)}%").join("\n");
        });
      } else if (mounted) {
        setState(() => _predictionResult = "CIFAR test failed: ${response.body}");
      }
    } catch (e) {
      if (mounted) setState(() => _predictionResult = "Error: $e");
    }
  }

  Future<void> _pickDataset() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    if (result != null && mounted) {
      setState(() => _selectedFile = result.files.first);
    }
  }

  Future<void> _pickImageFromGallery() async {
    final XFile? image = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (image != null && mounted) {
      setState(() => _predictionImage = File(image.path));
    }
  }

  Future<void> _captureImageFromCamera() async {
    final XFile? image = await _imagePicker.pickImage(source: ImageSource.camera);
    if (image != null && mounted) {
      setState(() => _predictionImage = File(image.path));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("NeuralNT Dashboard"),
        elevation: 0,
        bottom: _buildConnectionStatus(),
        actions: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Row(
                children: [
                  Icon(
                    _isConnected ? Icons.cloud_done : Icons.cloud_off,
                    color: _isConnected ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _isConnected ? (_apiAvailable ? "API Ready" : "No API") : "Offline",
                    style: TextStyle(
                      color: _isConnected && _apiAvailable ? Colors.green : Colors.red,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _checkConnectivity,
                  )
                ],
              ),
            ),
          ),
        ],
      ),
      body: !_isConnected
          ? _buildOfflineWidget()
          : !_apiAvailable
              ? _buildNoApiWidget()
              : _buildMainContent(),
      floatingActionButton: FloatingActionButton(
        onPressed: _checkConnectivity,
        tooltip: "Refresh Connection",
        child: const Icon(Icons.refresh),
      ),
    );
  }

  PreferredSizeWidget _buildConnectionStatus() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(4),
      child: Container(
        height: 4,
        color: _apiAvailable ? Colors.green : (_isConnected ? Colors.orange : Colors.red),
      ),
    );
  }

  Widget _buildOfflineWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off, size: 80, color: Colors.red),
          const SizedBox(height: 16),
          Text("No Internet Connection", style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          const Text("Please check your WiFi or mobile data connection."),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _checkConnectivity,
            child: const Text("Retry"),
          ),
        ],
      ),
    );
  }

  Widget _buildNoApiWidget() {
    return SingleChildScrollView(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.storage, size: 80, color: Colors.orange),
              const SizedBox(height: 16),
              Text("API Unavailable", style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              const Text("Make sure the backend server is running."),
              const SizedBox(height: 32),
              Card(
                color: Colors.black12,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Configure Backend Server",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        decoration: const InputDecoration(
                          labelText: "Server IP (e.g., 192.168.1.42)",
                          hintText: "Enter your PC IP address",
                          border: OutlineInputBorder(),
                        ),
                        controller: _serverAddressController,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        decoration: const InputDecoration(
                          labelText: "Port (default: 8000)",
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        controller: _serverPortController,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            _applyServerConfig();
                            _checkConnectivity();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.withOpacity(0.3),
                          ),
                          child: const Text("Apply & Connect"),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _checkConnectivity,
                child: const Text("Retry"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    return Row(
      children: [
        NavigationRail(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (int index) {
            setState(() => _selectedIndex = index);
          },
          labelType: NavigationRailLabelType.all,
          destinations: const [
            NavigationRailDestination(icon: Icon(Icons.build), label: Text('Build')),
            NavigationRailDestination(icon: Icon(Icons.model_training), label: Text('Train')),
            NavigationRailDestination(icon: Icon(Icons.remove_red_eye), label: Text('Test')),
          ],
        ),
        const VerticalDivider(thickness: 1, width: 1),
        Expanded(
          child: _selectedIndex == 0 ? _buildTab() : (_selectedIndex == 1 ? _trainTab() : _predictTab()),
        ),
      ],
    );
  }

  Widget _buildTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Model Architecture", style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 16),
          Card(
            color: Colors.black12,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Backend URL", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: const InputDecoration(labelText: "Host (IP/domain)", hintText: "192.168.1.42"),
                          controller: _serverAddressController,
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 100,
                        child: TextField(
                          decoration: const InputDecoration(labelText: "Port"),
                          keyboardType: TextInputType.number,
                          controller: _serverPortController,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _applyServerConfig,
                        child: const Text("Apply"),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text("Current: $baseUrl", style: const TextStyle(fontSize: 12, color: Colors.white70)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.deepPurple, width: 2),
            ),
            child: Text(
              _architectureText.isEmpty ? "No layers added yet." : _architectureText,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
            ),
          ),
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 16),
          Text("Add Layer", style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _layerButton("Linear"),
              _layerButton("Conv2d"),
              _layerButton("ReLU"),
              _layerButton("MaxPool2d"),
              _layerButton("Flatten"),
              _layerButton("Dropout"),
            ],
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () async {
              await http.post(Uri.parse("$baseUrl/reset"));
              _fetchArchitecture();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Architecture reset")),
              );
            },
            icon: const Icon(Icons.delete_forever),
            label: const Text("Reset Architecture"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.withOpacity(0.3),
              foregroundColor: Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Widget _layerButton(String type) {
    return ActionChip(
      label: Text(type),
      onPressed: () => _showAddLayerDialog(type),
    );
  }

  void _showAddLayerDialog(String type) {
    if (type == "ReLU" || type == "Flatten") {
      _addLayer(type, "", "");
      return;
    }

    final inCtrl = TextEditingController();
    final outCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Add $type Layer"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: inCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Input Dimension"),
            ),
            TextField(
              controller: outCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Output Dimension"),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              _addLayer(type, inCtrl.text, outCtrl.text);
              Navigator.pop(context);
            },
            child: const Text("Add"),
          )
        ],
      ),
    );
  }

  Widget _trainTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Train Model", style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Configuration", style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedLoss,
                    decoration: const InputDecoration(labelText: "Loss Function"),
                    items: ["CrossEntropyLoss", "MSELoss"]
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedLoss = v!),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedOptimizer,
                    decoration: const InputDecoration(labelText: "Optimizer"),
                    items: ["Adam", "SGD"]
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedOptimizer = v!),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _lrController,
                    decoration: const InputDecoration(labelText: "Learning Rate"),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _batchController,
                    decoration: const InputDecoration(labelText: "Batch Size"),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _sizeController,
                    decoration: const InputDecoration(labelText: "Image Size"),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _epochController,
                    decoration: const InputDecoration(labelText: "Epochs"),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _pickDataset,
            icon: const Icon(Icons.file_open),
            label: Text(_selectedFile == null ? "Select Dataset (.zip)" : "Selected: ${_selectedFile!.name}"),
          ),
          const SizedBox(height: 16),
          if (_isTraining)
            const LinearProgressIndicator()
          else
            ElevatedButton(
              onPressed: _startTraining,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.withOpacity(0.3),
                foregroundColor: Colors.green,
                minimumSize: const Size.fromHeight(50),
              ),
              child: const Text("START TRAINING", style: TextStyle(fontSize: 16)),
            ),
          const SizedBox(height: 24),
          const Divider(),
          Text("Training Logs", style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            height: 200,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black45,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey),
            ),
            child: SingleChildScrollView(
              child: Text(
                _trainingLogs.isEmpty ? "Logs will appear here..." : _trainingLogs,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _predictTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Text("Test Model", style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 24),
          if (_predictionImage != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                _predictionImage!,
                height: 250,
                width: 250,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 16),
          ] else
            Container(
              height: 250,
              width: 250,
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.deepPurple, width: 2, style: BorderStyle.solid),
              ),
              child: const Icon(Icons.image, size: 80, color: Colors.deepPurple),
            ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                onPressed: _pickImageFromGallery,
                icon: const Icon(Icons.photo_library),
                label: const Text("Gallery"),
              ),
              ElevatedButton.icon(
                onPressed: _captureImageFromCamera,
                icon: const Icon(Icons.camera_alt),
                label: const Text("Camera"),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (_isPredicting)
            const Column(
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text("Running inference..."),
              ],
            )
          else
            Column(
              children: [
                ElevatedButton(
                  onPressed: _runPrediction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.withOpacity(0.3),
                    foregroundColor: Colors.orange,
                    minimumSize: const Size.fromHeight(50),
                  ),
                  child: const Text("RUN PREDICTION", style: TextStyle(fontSize: 16)),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _runCifarTest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent.withOpacity(0.3),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50),
                  ),
                  child: const Text("RUN CIFAR TEST", style: TextStyle(fontSize: 16)),
                ),
              ],
            ),
          const SizedBox(height: 32),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black45,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.deepPurple),
            ),
            child: Text(
              _predictionResult.isEmpty ? "Results will appear here..." : _predictionResult,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orangeAccent),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _lrController.dispose();
    _batchController.dispose();
    _sizeController.dispose();
    _epochController.dispose();
    super.dispose();
  }
}
