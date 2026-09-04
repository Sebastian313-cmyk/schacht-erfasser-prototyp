package com.example.erfasser_app

import android.content.ContentValues
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream

class MainActivity : FlutterActivity() {
	private val channelName = "com.example.erfasser_app/export_storage"

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
			.setMethodCallHandler { call, result ->
				when (call.method) {
					"saveToDownloads" -> {
						val fileName = call.argument<String>("fileName")
						val relativeDir = call.argument<String>("relativeDir")
						val bytes = call.argument<ByteArray>("bytes")

						if (fileName.isNullOrBlank() || relativeDir.isNullOrBlank() || bytes == null) {
							result.error("invalid_args", "Missing fileName/relativeDir/bytes", null)
							return@setMethodCallHandler
						}

						try {
							result.success(saveToDownloads(fileName, relativeDir, bytes))
						} catch (e: Exception) {
							result.error("save_failed", e.message, null)
						}
					}
					"saveToDownloadsFromPath" -> {
						val fileName = call.argument<String>("fileName")
						val relativeDir = call.argument<String>("relativeDir")
						val sourcePath = call.argument<String>("sourcePath")

						if (fileName.isNullOrBlank() || relativeDir.isNullOrBlank() || sourcePath.isNullOrBlank()) {
							result.error("invalid_args", "Missing fileName/relativeDir/sourcePath", null)
							return@setMethodCallHandler
						}

						try {
							result.success(saveToDownloadsFromPath(fileName, relativeDir, sourcePath))
						} catch (e: Exception) {
							result.error("save_failed", e.message, null)
						}
					}
					else -> result.notImplemented()
				}
			}
	}

	private fun saveToDownloads(fileName: String, relativeDir: String, bytes: ByteArray): String {
		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
			val values = ContentValues().apply {
				put(MediaStore.Downloads.DISPLAY_NAME, fileName)
				put(MediaStore.Downloads.MIME_TYPE, guessMimeType(fileName))
				put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS + File.separator + relativeDir)
				put(MediaStore.Downloads.IS_PENDING, 1)
			}

			val resolver = applicationContext.contentResolver
			val itemUri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
				?: throw IllegalStateException("Could not create MediaStore item")

			resolver.openOutputStream(itemUri)?.use { out ->
				out.write(bytes)
				out.flush()
			} ?: throw IllegalStateException("Could not open output stream")

			values.clear()
			values.put(MediaStore.Downloads.IS_PENDING, 0)
			resolver.update(itemUri, values, null, null)

			return "Download${File.separator}$relativeDir${File.separator}$fileName"
		}

		val root = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
		val targetDir = File(root, relativeDir)
		if (!targetDir.exists()) targetDir.mkdirs()
		val targetFile = File(targetDir, fileName)
		targetFile.writeBytes(bytes)
		return targetFile.absolutePath
	}

	private fun saveToDownloadsFromPath(fileName: String, relativeDir: String, sourcePath: String): String {
		val source = File(sourcePath)
		if (!source.exists()) {
			throw IllegalStateException("Source file not found: $sourcePath")
		}

		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
			val values = ContentValues().apply {
				put(MediaStore.Downloads.DISPLAY_NAME, fileName)
				put(MediaStore.Downloads.MIME_TYPE, guessMimeType(fileName))
				put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS + File.separator + relativeDir)
				put(MediaStore.Downloads.IS_PENDING, 1)
			}

			val resolver = applicationContext.contentResolver
			val itemUri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
				?: throw IllegalStateException("Could not create MediaStore item")

			FileInputStream(source).use { input ->
				resolver.openOutputStream(itemUri)?.use { out ->
					input.copyTo(out)
					out.flush()
				} ?: throw IllegalStateException("Could not open output stream")
			}

			values.clear()
			values.put(MediaStore.Downloads.IS_PENDING, 0)
			resolver.update(itemUri, values, null, null)

			return "Download${File.separator}$relativeDir${File.separator}$fileName"
		}

		val root = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
		val targetDir = File(root, relativeDir)
		if (!targetDir.exists()) targetDir.mkdirs()
		val targetFile = File(targetDir, fileName)
		FileInputStream(source).use { input ->
			targetFile.outputStream().use { output ->
				input.copyTo(output)
				output.flush()
			}
		}
		return targetFile.absolutePath
	}

	private fun guessMimeType(fileName: String): String {
		val lower = fileName.lowercase()
		return when {
			lower.endsWith(".zip") -> "application/zip"
			lower.endsWith(".pdf") -> "application/pdf"
			lower.endsWith(".jpg") || lower.endsWith(".jpeg") -> "image/jpeg"
			lower.endsWith(".png") -> "image/png"
			lower.endsWith(".mp4") -> "video/mp4"
			else -> "application/octet-stream"
		}
	}
}
