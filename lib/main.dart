import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_ml_kit/google_ml_kit.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: ImagePickerScreen(),
    );
  }
}

class ImagePickerScreen extends StatefulWidget {
  @override
  _ImagePickerScreenState createState() => _ImagePickerScreenState();
}

class _ImagePickerScreenState extends State<ImagePickerScreen> {
  late File _image;
  bool _imageSelected = false;
  String result = '';
  String prob = '';
  String detectionTime = '';
  String serverProcessingTime = '';
  String totalTime = '';
  String cpuUsage = 'CPU Usage: N/A'; // 修改为 N/A
  late DateTime _startTime;
  late DateTime _detectionStartTime;
  late DateTime _serverStartTime;
  late PoseDetector _poseDetector;

  @override
  void initState() {
    super.initState();
    _poseDetector = PoseDetector(
      options: PoseDetectorOptions(
        model: PoseDetectionModel.base,
        mode: PoseDetectionMode.stream,
      ),
    );
  }

  Future<void> _pickAndProcessImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
        _imageSelected = true;
      });

      _startTime = DateTime.now(); // 记录总开始时间
      _detectionStartTime = DateTime.now(); // 记录检测开始时间

      // Convert the image to InputImage for pose detection
      final inputImage = InputImage.fromFile(_image);

      // Detect pose
      try {
        final List<Pose> detectedPoses = await _poseDetector.processImage(inputImage);

        // 记录检测结束时间
        final detectionEndTime = DateTime.now();
        final detectionDuration = detectionEndTime.difference(_detectionStartTime).inMilliseconds;
        detectionTime = 'Detection time: $detectionDuration ms';

        // Convert the detected pose to JSON format
        final List<Map<String, dynamic>> jsonPoses = detectedPoses.map((pose) {
          final Map<String, dynamic> poseMap = {};
          for (var landmark in pose.landmarks.values) {
            final Map<String, dynamic> landmarkMap = {
              "x": landmark.x.toStringAsFixed(2),
              "y": landmark.y.toStringAsFixed(2),
              "z": 0.0,
              "v": landmark.likelihood.toStringAsFixed(2)
            };
            poseMap[landmark.type.toString()] = landmarkMap;
          }
          return poseMap;
        }).toList();

        // Send the JSON result to the server
        await _sendJsonToServer(jsonPoses);

      } catch (e) {
        print("Error detecting pose: $e");
      }
    }
  }

  Future<void> _sendJsonToServer(List<Map<String, dynamic>> jsonPoses) async {
    _serverStartTime = DateTime.now(); // 记录服务器处理开始时间

    try {
      final response = await http.post(
        Uri.parse('https://mp-hdkf.onrender.com/predict/warrior'), // 更改为你的服务器地址
        body: jsonEncode({'jsonPoses': jsonPoses}),
        headers: {'Content-Type': 'application/json'},
      );

      // 记录服务器处理结束时间
      final serverEndTime = DateTime.now();
      final serverDuration = serverEndTime.difference(_serverStartTime).inMilliseconds;
      serverProcessingTime = 'Server processing time: $serverDuration ms';

      if (response.statusCode == 200) {
        // Handle server response here
        final responseData = jsonDecode(response.body);
        setState(() {
          result = responseData['body_language_class'].toString();
          prob = responseData['body_language_prob'].toString();
          final totalDuration = DateTime.now().difference(_startTime).inMilliseconds;
          totalTime = 'Total time: $totalDuration ms';
        });
      } else {
        print('Failed to send pose data to the server. Status code: ${response.statusCode}');
        print('Response body: ${response.body}');
      }
    } catch (e) {
      print("Error sending pose data to server: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Pose Detection Example')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            _imageSelected
                ? Image.file(_image, width: 300, height: 300) // 显示所选的图片
                : Text('No image selected.'),
            ElevatedButton(
              onPressed: _pickAndProcessImage,
              child: Text('Select Image and Detect Pose'),
            ),
            Text('Result: $result $prob'),
            Text(detectionTime), // 显示检测时间
            Text(serverProcessingTime), // 显示服务器处理时间
            Text(totalTime), // 显示总时间
            Text(cpuUsage), // 显示 CPU 使用率
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _poseDetector.close(); // 释放资源
    super.dispose();
  }
}
