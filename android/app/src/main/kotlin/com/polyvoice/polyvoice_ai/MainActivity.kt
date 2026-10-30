package com.polyvoice.polyvoice_ai

import android.app.Activity
import android.content.Intent
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import android.media.MediaMuxer
import android.media.MediaPlayer
import android.net.Uri
import android.webkit.MimeTypeMap
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.nio.ByteBuffer

class MainActivity : FlutterActivity() {
    private val CHANNEL_NAME = "com.polyvoice.polyvoice_ai/media_native"
    private val PICK_FILE_REQUEST_CODE = 9021

    private var pendingPickerResult: MethodChannel.Result? = null
    private var mediaPlayer: MediaPlayer? = null
    private var methodChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "pickMediaFile" -> {
                    val mediaType = call.argument<String>("type") ?: "audio"
                    pendingPickerResult = result
                    launchFilePicker(mediaType)
                }
                "extractAudioFromVideo" -> {
                    val videoPath = call.argument<String>("videoPath")
                    val outputPath = call.argument<String>("outputPath")
                    if (videoPath == null || outputPath == null) {
                        result.error("INVALID_ARGS", "Missing videoPath or outputPath", null)
                        return@setMethodCallHandler
                    }
                    extractAudio(videoPath, outputPath, result)
                }
                "playAudio" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath == null) {
                        result.error("INVALID_ARGS", "Missing filePath", null)
                        return@setMethodCallHandler
                    }
                    playAudioFile(filePath, result)
                }
                "stopAudio" -> {
                    stopAudioPlayback()
                    result.success(true)
                }
                "isAudioPlaying" -> {
                    result.success(mediaPlayer?.isPlaying == true)
                }
                "getAudioMetadata" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath == null) {
                        result.error("INVALID_ARGS", "Missing filePath", null)
                        return@setMethodCallHandler
                    }
                    extractMetadata(filePath, result)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun launchFilePicker(mediaType: String) {
        val intent = Intent(Intent.ACTION_GET_CONTENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            when (mediaType.lowercase()) {
                "audio" -> {
                    type = "audio/*"
                    putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("audio/*", "application/ogg", "audio/mp4", "audio/x-m4a"))
                }
                "video" -> {
                    type = "video/*"
                    putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("video/*", "video/mp4", "video/quicktime", "video/x-matroska"))
                }
                else -> {
                    type = "*/*"
                    putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("audio/*", "video/*"))
                }
            }
        }
        try {
            startActivityForResult(Intent.createChooser(intent, "Chọn file âm thanh hoặc video"), PICK_FILE_REQUEST_CODE)
        } catch (e: Exception) {
            pendingPickerResult?.error("PICK_FAILED", "Failed to launch picker: ${e.message}", null)
            pendingPickerResult = null
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        if (requestCode == PICK_FILE_REQUEST_CODE) {
            if (resultCode == Activity.RESULT_OK && data?.data != null) {
                val uri = data.data!!
                Thread {
                    try {
                        val extension = getExtensionFromUri(uri)
                        val cacheFile = File(cacheDir, "imported_${System.currentTimeMillis()}.$extension")
                        contentResolver.openInputStream(uri)?.use { input ->
                            FileOutputStream(cacheFile).use { output ->
                                input.copyTo(output)
                            }
                        }
                        runOnUiThread {
                            pendingPickerResult?.success(cacheFile.absolutePath)
                            pendingPickerResult = null
                        }
                    } catch (e: Exception) {
                        runOnUiThread {
                            pendingPickerResult?.error("COPY_FAILED", "Failed to copy media file: ${e.message}", null)
                            pendingPickerResult = null
                        }
                    }
                }.start()
            } else {
                pendingPickerResult?.success(null)
                pendingPickerResult = null
            }
        }
    }

    private fun getExtensionFromUri(uri: Uri): String {
        val mimeType = contentResolver.getType(uri)
        if (mimeType != null) {
            val ext = MimeTypeMap.getSingleton().getExtensionFromMimeType(mimeType)
            if (!ext.isNullOrEmpty()) return ext
        }
        val path = uri.path ?: ""
        val lastDot = path.lastIndexOf('.')
        if (lastDot >= 0 && lastDot < path.length - 1) {
            return path.substring(lastDot + 1)
        }
        return "m4a"
    }

    private fun extractAudio(videoPath: String, outputPath: String, result: MethodChannel.Result) {
        Thread {
            try {
                val extractor = MediaExtractor()
                extractor.setDataSource(videoPath)
                var audioTrackIndex = -1
                var audioFormat: MediaFormat? = null

                for (i in 0 until extractor.trackCount) {
                    val format = extractor.getTrackFormat(i)
                    val mime = format.getString(MediaFormat.KEY_MIME) ?: ""
                    if (mime.startsWith("audio/")) {
                        audioTrackIndex = i
                        audioFormat = format
                        break
                    }
                }

                if (audioTrackIndex < 0 || audioFormat == null) {
                    runOnUiThread {
                        result.error("NO_AUDIO", "Video không chứa luồng âm thanh hợp lệ.", null)
                    }
                    extractor.release()
                    return@Thread
                }

                extractor.selectTrack(audioTrackIndex)
                val outFile = File(outputPath)
                if (outFile.exists()) outFile.delete()
                outFile.parentFile?.mkdirs()

                val muxer = MediaMuxer(outputPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
                val muxerTrack = muxer.addTrack(audioFormat)
                muxer.start()

                val maxBufferSize = if (audioFormat.containsKey(MediaFormat.KEY_MAX_INPUT_SIZE)) {
                    audioFormat.getInteger(MediaFormat.KEY_MAX_INPUT_SIZE)
                } else {
                    1024 * 1024
                }
                val buffer = ByteBuffer.allocate(maxBufferSize)
                val bufferInfo = MediaCodec.BufferInfo()

                while (true) {
                    bufferInfo.offset = 0
                    bufferInfo.size = extractor.readSampleData(buffer, 0)
                    if (bufferInfo.size < 0) {
                        break
                    }
                    bufferInfo.presentationTimeUs = extractor.sampleTime
                    bufferInfo.flags = extractor.sampleFlags
                    muxer.writeSampleData(muxerTrack, buffer, bufferInfo)
                    extractor.advance()
                }

                muxer.stop()
                muxer.release()
                extractor.release()

                runOnUiThread {
                    result.success(outputPath)
                }
            } catch (e: Exception) {
                runOnUiThread {
                    result.error("EXTRACT_FAILED", "Trích xuất âm thanh từ video thất bại: ${e.message}", null)
                }
            }
        }.start()
    }

    private fun playAudioFile(filePath: String, result: MethodChannel.Result) {
        try {
            stopAudioPlayback()
            mediaPlayer = MediaPlayer().apply {
                setDataSource(filePath)
                prepare()
                setOnCompletionListener {
                    runOnUiThread {
                        methodChannel?.invokeMethod("onAudioPlaybackCompleted", null)
                    }
                }
                start()
            }
            result.success(true)
        } catch (e: Exception) {
            result.error("PLAY_FAILED", "Không thể phát âm thanh: ${e.message}", null)
        }
    }

    private fun stopAudioPlayback() {
        try {
            mediaPlayer?.stop()
            mediaPlayer?.release()
        } catch (_: Exception) {}
        mediaPlayer = null
    }

    private fun extractMetadata(filePath: String, result: MethodChannel.Result) {
        try {
            val file = File(filePath)
            if (!file.exists()) {
                result.error("NOT_FOUND", "File không tồn tại", null)
                return
            }
            val retriever = MediaMetadataRetriever()
            retriever.setDataSource(filePath)
            val durationStr = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
            val mimeType = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_MIMETYPE)
            val hasAudio = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_HAS_AUDIO)
            retriever.release()

            val durationMs = durationStr?.toLongOrNull() ?: 0L
            val metaMap = mapOf(
                "durationMs" to durationMs,
                "mimeType" to (mimeType ?: "audio/mpeg"),
                "hasAudio" to (hasAudio == "yes" || hasAudio != null),
                "fileSizeBytes" to file.length()
            )
            result.success(metaMap)
        } catch (e: Exception) {
            val file = File(filePath)
            val fallbackMap = mapOf(
                "durationMs" to 0L,
                "mimeType" to "audio/mpeg",
                "hasAudio" to true,
                "fileSizeBytes" to if (file.exists()) file.length() else 0L
            )
            result.success(fallbackMap)
        }
    }

    override fun onDestroy() {
        stopAudioPlayback()
        super.onDestroy()
    }
}
