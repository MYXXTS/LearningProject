package com.example.bike

import android.Manifest
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothSocket
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.OutputStream
import java.util.UUID
import kotlin.concurrent.thread

class MainActivity : FlutterActivity() {
    private val methodChannelName = "bike/bluetooth_method"
    private val connectionChannelName = "bike/bluetooth_connection"
    private val lineChannelName = "bike/bluetooth_line"
    private val errorChannelName = "bike/bluetooth_error"
    private val permissionRequestCode = 9001
    private val sppUuid: UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")

    private val mainHandler = Handler(Looper.getMainLooper())

    @Volatile
    private var btSocket: BluetoothSocket? = null

    @Volatile
    private var btOutput: OutputStream? = null

    @Volatile
    private var readerThread: Thread? = null

    private var connectionSink: EventChannel.EventSink? = null
    private var lineSink: EventChannel.EventSink? = null
    private var errorSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, methodChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "ensurePermissions" -> result.success(ensureBluetoothPermissions())
                    "isBluetoothEnabled" -> result.success(getBluetoothAdapter()?.isEnabled == true)
                    "openBluetoothSettings" -> {
                        startActivity(Intent(Settings.ACTION_BLUETOOTH_SETTINGS))
                        result.success(true)
                    }
                    "connect" -> {
                        val mac = call.argument<String>("macAddress")
                        if (mac.isNullOrBlank()) {
                            emitError("蓝牙 MAC 地址为空。")
                            result.success(false)
                        } else {
                            result.success(connectToDevice(mac))
                        }
                    }
                    "disconnect" -> {
                        disconnectSocket()
                        result.success(true)
                    }
                    "sendLine" -> {
                        val line = call.argument<String>("line")
                        result.success(sendLine(line))
                    }
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, connectionChannelName)
            .setStreamHandler(simpleStreamHandler(
                onListen = { sink ->
                    connectionSink = sink
                    emitConnectionState(if (btSocket != null) "connected" else "disconnected")
                },
                onCancel = { connectionSink = null },
            ))

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, lineChannelName)
            .setStreamHandler(simpleStreamHandler(
                onListen = { sink -> lineSink = sink },
                onCancel = { lineSink = null },
            ))

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, errorChannelName)
            .setStreamHandler(simpleStreamHandler(
                onListen = { sink -> errorSink = sink },
                onCancel = { errorSink = null },
            ))
    }

    override fun onDestroy() {
        disconnectSocket()
        super.onDestroy()
    }

    private fun simpleStreamHandler(
        onListen: (EventChannel.EventSink) -> Unit,
        onCancel: () -> Unit,
    ): EventChannel.StreamHandler {
        return object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                onListen(events)
            }

            override fun onCancel(arguments: Any?) {
                onCancel()
            }
        }
    }

    private fun getBluetoothAdapter(): BluetoothAdapter? {
        val manager = getSystemService(BLUETOOTH_SERVICE) as? BluetoothManager
        return manager?.adapter
    }

    private fun ensureBluetoothPermissions(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            return true
        }

        val missing = mutableListOf<String>()
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH_CONNECT) != PackageManager.PERMISSION_GRANTED) {
            missing.add(Manifest.permission.BLUETOOTH_CONNECT)
        }
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH_SCAN) != PackageManager.PERMISSION_GRANTED) {
            missing.add(Manifest.permission.BLUETOOTH_SCAN)
        }

        if (missing.isEmpty()) {
            return true
        }

        ActivityCompat.requestPermissions(this, missing.toTypedArray(), permissionRequestCode)
        return false
    }

    private fun hasBluetoothConnectPermission(): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
            ContextCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED
    }

    private fun emitConnectionState(state: String) {
        mainHandler.post {
            connectionSink?.success(state)
        }
    }

    private fun emitLine(line: String) {
        mainHandler.post {
            lineSink?.success(line)
        }
    }

    private fun emitError(message: String) {
        mainHandler.post {
            errorSink?.success(message)
        }
    }

    private fun connectToDevice(macAddress: String): Boolean {
        val adapter = getBluetoothAdapter()
        if (adapter == null) {
            emitError("设备不支持蓝牙。")
            return false
        }

        if (!adapter.isEnabled) {
            emitError("蓝牙未开启。")
            return false
        }

        if (!ensureBluetoothPermissions() || !hasBluetoothConnectPermission()) {
            emitError("蓝牙权限尚未授予。")
            return false
        }

        if (!BluetoothAdapter.checkBluetoothAddress(macAddress)) {
            emitError("蓝牙 MAC 地址格式不正确。")
            return false
        }

        disconnectSocket()
        emitConnectionState("connecting")

        thread(name = "bike-bt-connect") {
            try {
                val device: BluetoothDevice = adapter.getRemoteDevice(macAddress)
                if (device.bondState != BluetoothDevice.BOND_BONDED) {
                    emitError("HC-06 尚未在系统蓝牙设置中完成配对。")
                    emitConnectionState("disconnected")
                    return@thread
                }

                adapter.cancelDiscovery()
                val socket = device.createRfcommSocketToServiceRecord(sppUuid)
                socket.connect()

                btSocket = socket
                btOutput = socket.outputStream
                emitConnectionState("connected")
                startReader(socket)
            } catch (e: Exception) {
                emitError("蓝牙连接失败：${e.message ?: "未知错误"}")
                disconnectSocket()
            }
        }

        return true
    }

    private fun startReader(socket: BluetoothSocket) {
        readerThread?.interrupt()
        readerThread = thread(name = "bike-bt-reader") {
            val builder = StringBuilder()
            try {
                val input = socket.inputStream
                val buffer = ByteArray(256)

                while (!Thread.currentThread().isInterrupted) {
                    val count = input.read(buffer)
                    if (count <= 0) {
                        break
                    }

                    for (index in 0 until count) {
                        val ch = buffer[index].toInt().toChar()
                        when (ch) {
                            '\n' -> {
                                emitLine(builder.toString())
                                builder.setLength(0)
                            }
                            '\r' -> {}
                            else -> builder.append(ch)
                        }
                    }
                }
            } catch (e: Exception) {
                emitError("蓝牙接收失败：${e.message ?: "未知错误"}")
            } finally {
                disconnectSocket()
            }
        }
    }

    private fun sendLine(line: String?): Boolean {
        if (line.isNullOrBlank()) {
            emitError("发送指令为空。")
            return false
        }

        val output = btOutput
        if (output == null) {
            emitError("蓝牙尚未连接。")
            return false
        }

        return try {
            val payload = if (line.endsWith("\n")) line else "$line\n"
            synchronized(this) {
                output.write(payload.toByteArray(Charsets.UTF_8))
                output.flush()
            }
            true
        } catch (e: Exception) {
            emitError("蓝牙发送失败：${e.message ?: "未知错误"}")
            false
        }
    }

    private fun disconnectSocket() {
        try {
            readerThread?.interrupt()
        } catch (_: Exception) {
        }
        readerThread = null

        try {
            btOutput?.close()
        } catch (_: Exception) {
        }
        btOutput = null

        try {
            btSocket?.close()
        } catch (_: Exception) {
        }
        btSocket = null

        emitConnectionState("disconnected")
    }
}
