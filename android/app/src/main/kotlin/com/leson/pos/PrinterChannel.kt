package com.leson.pos

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class PrinterChannel private constructor(
    private val context: Context,
    messenger: io.flutter.plugin.common.BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    private val channel = MethodChannel(messenger, CHANNEL_NAME)

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != METHOD_PRINT_DIRECT) {
            result.notImplemented()
            return
        }

        val payload = call.arguments as? Map<*, *>
        if (payload == null) {
            result.success(mapOf("ok" to false, "error" to "Invalid payload"))
            return
        }

        val handler = Handler(Looper.getMainLooper())
        Thread {
            val response = try {
                EpsonPrinterService(context).printReceipt(payload)
            } catch (t: Throwable) {
                mapOf("ok" to false, "error" to (t.message ?: "Unknown error"))
            }
            handler.post { result.success(response) }
        }.start()
    }

    companion object {
        private const val CHANNEL_NAME = "leson.pos/printer"
        private const val METHOD_PRINT_DIRECT = "printDirect"

        fun register(flutterEngine: FlutterEngine, context: Context) {
            PrinterChannel(context, flutterEngine.dartExecutor.binaryMessenger)
        }
    }
}
