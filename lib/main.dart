
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Android 13+ ke liye storage permission
  if (await Permission.storage.request().isGranted ||
      await Permission.manageExternalStorage.request().isGranted) {
    // Permission granted
  }
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // This holds the path to the custom font file we saved
  String? _customFontPath;
  // Flag to rebuild UI after font loads
  bool _fontLoaded = false;

  Future<void> _pickAndInstallFont() async {
    try {
      // 1. Pick .ttf file from phone storage
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['ttf', 'otf'],
      );

      if (result == null) return;

      // 2. Copy font to app's private directory (so it stays even if source file is deleted)
      final appDir = await getApplicationDocumentsDirectory();
      final savedPath = '${appDir.path}/custom_font.ttf';
      File savedFont = await File(result.files.single.path!).copy(savedPath);

      // 3. Load font dynamically using FontLoader
      final fontBytes = await savedFont.readAsBytes();
      final fontLoader = FontLoader('CustomFont')
        ..addFont(Future.value(ByteData.view(fontBytes.buffer)));
      await fontLoader.load();

      // 4. Update state to rebuild UI with new font
      setState(() {
        _customFontPath = savedPath;
        _fontLoaded = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Custom Font Installed Successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error loading font: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Doc Editor Pro',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        // Font family ko globally set kar rahe hain agar loaded hai toh
        fontFamily: _fontLoaded ? 'CustomFont' : 'Roboto',
      ),
      home: HomePage(
        onFontInstall: _pickAndInstallFont,
        isCustomFontActive: _fontLoaded,
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  final VoidCallback onFontInstall;
  final bool isCustomFontActive;

  const HomePage({
    super.key,
    required this.onFontInstall,
    required this.isCustomFontActive,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _currentFilePath = '';
  bool _isPdf = false;
  bool _isText = false;
  String _textContent = '';
  late quill.QuillController _quillController;

  @override
  void initState() {
    super.initState();
    _quillController = quill.QuillController.basic();
  }

  Future<void> _pickDocument() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'txt', 'md', 'docx'],
    );

    if (result != null) {
      String path = result.files.single.path!;
      setState(() {
        _currentFilePath = path;
        _isPdf = path.endsWith('.pdf');
        _isText = path.endsWith('.txt') || path.endsWith('.md');
        
        if (_isText) {
          _textContent = File(path).readAsStringSync();
          // Quill editor mein content set karna
          _quillController.document = quill.Document.fromJson(
            [{'insert': _textContent}]
          );
        } else if (path.endsWith('.docx')) {
          // Note: Full DOCX editing requires complex libs; isme sirf viewer hai
          // For real DOCX, try `flutter_quill` with `quill_delta` but keeping it simple.
          _isText = true; 
          _textContent = 'DOCX file selected. Full editing needs advanced package.';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'My Document Editor',
          style: TextStyle(
            // Agar font active hai toh custom font dikhega, warna default
            fontFamily: widget.isCustomFontActive ? 'CustomFont' : null,
          ),
        ),
        actions: [
          // Install Font Button
          IconButton(
            icon: const Icon(Icons.font_download),
            onPressed: widget.onFontInstall,
            tooltip: 'Install Custom TTF Font',
          ),
          // Open Document Button
          IconButton(
            icon: const Icon(Icons.folder_open),
            onPressed: _pickDocument,
            tooltip: 'Open Document',
          ),
        ],
      ),
      body: Column(
        children: [
          // Status bar for custom font
          if (widget.isCustomFontActive)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6),
              color: Colors.green.shade100,
              child: const Text(
                '🌟 Custom Font Active',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
              ),
            ),
          
          // Main Content Area
          Expanded(
            child: _currentFilePath.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.description, size: 60, color: Colors.grey),
                        SizedBox(height: 10),
                        Text(
                          'Open a PDF, TXT, or MD file',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : _isPdf
                    ? SfPdfViewer.file(File(_currentFilePath))
                    : _isText
                        ? quill.QuillEditor(
                            controller: _quillController,
                            configurations: const quill.QuillEditorConfigurations(
                              scrollable: true,
                              expands: true,
                              autoFocus: false,
                              placeholder: 'Edit your document here...',
                            ),
                          )
                        : const Center(child: Text('Unsupported file format')),
          ),
        ],
      ),
    );
  }
}
