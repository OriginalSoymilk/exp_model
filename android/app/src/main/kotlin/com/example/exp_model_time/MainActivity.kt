package com.example.exp_model_time

import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.BufferedReader
import java.io.FileReader
import java.io.IOException

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.exp_model_time/cpu"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "getCpuUsage") {
                    val cpuUsage = getCpuUsage()
                    result.success(cpuUsage)
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun getCpuUsage(): Double {
        var usage = 0.0
        try {
            val reader = BufferedReader(FileReader("/proc/stat"))
            val line = reader.readLine()
            reader.close()
            val cpuValues = line?.split("\\s+".toRegex())?.drop(1)?.take(4)?.map { it.toLong() }
            if (cpuValues != null && cpuValues.size == 4) {
                val total = cpuValues.sum()
                val idle = cpuValues[3]
                usage = (1 - idle.toDouble() / total) * 100
            }
        } catch (e: IOException) {
            e.printStackTrace()
        }
        return usage
    }
}
