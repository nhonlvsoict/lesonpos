package com.example.lesonpos

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.epson.epos2.Epos2Exception
import com.epson.epos2.printer.CommonPrinter
import com.epson.epos2.printer.Printer
import com.epson.epos2.printer.PrinterStatusInfo
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.text.NumberFormat
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import kotlin.math.max

class EpsonDirectPrinterPlugin private constructor(
    private val appContext: Context,
) : MethodChannel.MethodCallHandler {

    private val executor: ExecutorService = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            METHOD_IS_AVAILABLE -> handleIsAvailable(result)
            METHOD_PRINT_DIRECT -> handlePrintDirect(call.arguments, result)
            else -> result.notImplemented()
        }
    }

    private fun handleIsAvailable(result: MethodChannel.Result) {
        executor.execute {
            val available = try {
                Printer(Printer.TM_M30, CommonPrinter.MODEL_ANK, appContext).use { printer ->
                    printer.clearCommandBuffer()
                }
                true
            } catch (error: Throwable) {
                Log.w(TAG, "Epson printer SDK unavailable", error)
                false
            }
            mainHandler.post { result.success(available) }
        }
    }

    private fun handlePrintDirect(arguments: Any?, result: MethodChannel.Result) {
        val payload = arguments as? Map<*, *>
        if (payload == null) {
            result.success(failure("Invalid payload"))
            return
        }

        executor.execute {
            val response = executePrint(payload)
            mainHandler.post { result.success(response) }
        }
    }

    private fun executePrint(payload: Map<*, *>): Map<String, Any?> {
        val config = payload["config"] as? Map<*, *>
            ?: return failure("Missing printer config")
        val target = config["target"]?.toString()?.takeIf { it.isNotBlank() }
            ?: return failure("Missing printer target")
        val timeout = (config["timeout"] as? Number)?.toInt() ?: DEFAULT_TIMEOUT
        val modelName = config["model"]?.toString()?.uppercase(Locale.US) ?: DEFAULT_MODEL
        val langName = config["lang"]?.toString()?.uppercase(Locale.US) ?: DEFAULT_LANG
        val paperSize = PaperSize.fromConfig(config["paperSize"])
        val copies = max((payload["copies"] as? Number)?.toInt() ?: 1, 1)

        var printer: Printer? = null
        return try {
            printer = Printer(resolveModel(modelName), resolveLang(langName), appContext)
            printer.connect(target, timeout)
            printer.beginTransaction()

            repeat(copies) {
                printer.clearCommandBuffer()
                buildReceipt(printer, payload, paperSize)
                printer.sendData(CommonPrinter.PARAM_DEFAULT)
                checkPrinterStatus(printer.status)?.let { message ->
                    throw PrinterStatusException(message)
                }
            }

            printer.endTransaction()
            printer.disconnect()

            success(copies)
        } catch (status: PrinterStatusException) {
            Log.w(TAG, "Printer reported status error", status)
            failure(status.message ?: "Printer unavailable")
        } catch (error: Epos2Exception) {
            Log.w(TAG, "Epson SDK error", error)
            failure(describeEposError(error))
        } catch (error: Throwable) {
            Log.e(TAG, "Unexpected print failure", error)
            failure(error.message ?: "Unexpected error")
        } finally {
            try {
                printer?.endTransaction()
            } catch (_: Throwable) {
            }
            try {
                printer?.disconnect()
            } catch (_: Throwable) {
            }
            try {
                printer?.clearCommandBuffer()
            } catch (_: Throwable) {
            }
            printer?.setReceiveEventListener(null)
        }
    }

    private fun buildReceipt(printer: Printer, payload: Map<*, *>, paperSize: PaperSize) {
        val store = payload["store"] as? Map<*, *> ?: emptyMap<Any?, Any?>()
        val receipt = payload["receipt"] as? Map<*, *> ?: emptyMap<Any?, Any?>()
        val printOptions = payload["printOptions"] as? Map<*, *> ?: emptyMap<Any?, Any?>()
        val footerLines = (payload["footerLines"] as? List<*>)?.mapNotNull { it?.toString() } ?: emptyList()

        val currencyCode = receipt["currency"]?.toString()?.ifBlank { DEFAULT_CURRENCY } ?: DEFAULT_CURRENCY
        val currencyFormatter = NumberFormat.getCurrencyInstance(Locale.UK).apply {
            currency = try {
                java.util.Currency.getInstance(currencyCode)
            } catch (_: IllegalArgumentException) {
                java.util.Currency.getInstance(DEFAULT_CURRENCY)
            }
        }

        val createdAt = receipt["createdAt"]?.toString()
        val createdAtLabel = createdAt?.let { timestamp ->
            parseIsoDate(timestamp)?.let { date ->
                SimpleDateFormat("dd/MM/yyyy HH:mm", Locale.UK).apply {
                    timeZone = TimeZone.getDefault()
                }.format(date)
            }
        }

        val headerServer = receipt["server"]?.toString()?.takeIf { it.isNotBlank() }
        val table = receipt["table"]?.toString()?.ifBlank { null }
        val orderId = receipt["orderId"]?.toString()?.ifBlank { null }
        val note = receipt["note"]?.toString()?.ifBlank { null }

        printer.addTextAlign(CommonPrinter.ALIGN_CENTER)
        store["name"]?.toString()?.takeIf { it.isNotBlank() }?.let {
            printer.addTextStyle(CommonPrinter.FALSE, CommonPrinter.FALSE, CommonPrinter.FONT_A, CommonPrinter.COLOR_1)
            printer.addTextSize(2, 2)
            printer.addText("$it\n")
        }
        printer.addTextSize(1, 1)
        printer.addTextStyle(CommonPrinter.FALSE, CommonPrinter.FALSE, CommonPrinter.FONT_A, CommonPrinter.COLOR_1)
        store["address"]?.toString()?.takeIf { it.isNotBlank() }?.let {
            printer.addText("$it\n")
        }
        store["phone"]?.toString()?.takeIf { it.isNotBlank() }?.let {
            printer.addText("Tel: $it\n")
        }
        printer.addFeedLine(1)

        printer.addTextAlign(CommonPrinter.ALIGN_LEFT)
        createdAtLabel?.let { printer.addText("Date: $it\n") }
        table?.let { printer.addText("Table: $it\n") }
        orderId?.let { printer.addText("Order: $it\n") }
        headerServer?.let { printer.addText("Server: $it\n") }
        note?.let {
            printer.addText("Note: $it\n")
        }
        printer.addFeedLine(1)

        val items = (receipt["items"] as? List<*>)?.mapNotNull { it as? Map<*, *> } ?: emptyList()
        if (items.isNotEmpty()) {
            printer.addTextAlign(CommonPrinter.ALIGN_LEFT)
            for (item in items) {
                val qty = max((item["qty"] as? Number)?.toInt() ?: 0, 0)
                val name = item["name"]?.toString() ?: ""
                val unitPence = (item["unitPricePence"] as? Number)?.toInt()
                val lineTotalPence = when {
                    unitPence != null && qty > 0 -> unitPence * qty
                    else -> ((item["totalPricePence"] as? Number)?.toInt()) ?: 0
                }
                val priceText = currencyFormatter.format(lineTotalPence / 100.0)
                val label = "${qty} x $name"
                printer.addText(formatLine(label, priceText, paperSize.itemColumns))
                val itemNote = item["note"]?.toString()?.ifBlank { null }
                if (itemNote != null) {
                    printer.addText("  - $itemNote\n")
                }
            }
            printer.addFeedLine(1)
        }

        printer.addTextAlign(CommonPrinter.ALIGN_RIGHT)
        val subTotal = ((receipt["subTotalPence"] as? Number)?.toInt())
            ?: ((receipt["subTotal"] as? Number)?.toDouble()?.times(100))?.toInt()
        subTotal?.let {
            printer.addText("Subtotal: ${currencyFormatter.format(it / 100.0)}\n")
        }
        val serviceCharge = ((receipt["serviceChargePence"] as? Number)?.toInt())
            ?: ((receipt["serviceCharge"] as? Number)?.toDouble()?.times(100))?.toInt()
        serviceCharge?.takeIf { it > 0 }?.let {
            printer.addText("Service: ${currencyFormatter.format(it / 100.0)}\n")
        }
        val tax = ((receipt["taxPence"] as? Number)?.toInt())
            ?: ((receipt["tax"] as? Number)?.toDouble()?.times(100))?.toInt()
        tax?.takeIf { it > 0 }?.let {
            printer.addText("Tax: ${currencyFormatter.format(it / 100.0)}\n")
        }
        val discount = ((receipt["discountPence"] as? Number)?.toInt())
            ?: ((receipt["discount"] as? Number)?.toDouble()?.times(100))?.toInt()
        discount?.takeIf { it > 0 }?.let {
            printer.addText("Discount: -${currencyFormatter.format(it / 100.0)}\n")
        }
        val total = ((receipt["totalPence"] as? Number)?.toInt())
            ?: ((receipt["total"] as? Number)?.toDouble()?.times(100))?.toInt()
        total?.let {
            printer.addTextStyle(CommonPrinter.FALSE, CommonPrinter.FALSE, CommonPrinter.FONT_B, CommonPrinter.COLOR_1)
            printer.addText("TOTAL: ${currencyFormatter.format(it / 100.0)}\n")
            printer.addTextStyle(CommonPrinter.FALSE, CommonPrinter.FALSE, CommonPrinter.FONT_A, CommonPrinter.COLOR_1)
        }
        printer.addFeedLine(1)

        handleBarcode(printer, printOptions["printBarcode"])
        handleQr(printer, printOptions["printQr"])

        printer.addTextAlign(CommonPrinter.ALIGN_CENTER)
        if (footerLines.isNotEmpty()) {
            for (line in footerLines) {
                printer.addText("$line\n")
            }
            printer.addFeedLine(1)
        }

        val openDrawer = (printOptions["openDrawer"] as? Boolean) == true
        if (openDrawer) {
            printer.addPulse(CommonPrinter.DRAWER_2PIN, CommonPrinter.PULSE_100)
        }

        val cutType = printOptions["cutType"]?.toString()?.uppercase(Locale.US) ?: DEFAULT_CUT
        printer.addCut(resolveCutType(cutType))
    }

    private fun handleQr(printer: Printer, config: Any?) {
        val qr = config as? Map<*, *> ?: return
        val data = qr["data"]?.toString()?.takeIf { it.isNotBlank() } ?: return
        val size = (qr["size"] as? Number)?.toInt() ?: DEFAULT_QR_SIZE
        try {
            printer.addSymbol(
                data,
                CommonPrinter.SYMBOL_QRCODE_MODEL_2,
                CommonPrinter.LEVEL_M,
                size,
                size,
                CommonPrinter.PARAM_DEFAULT,
            )
            printer.addFeedLine(1)
        } catch (error: Epos2Exception) {
            Log.w(TAG, "Unable to add QR code", error)
        }
    }

    private fun handleBarcode(printer: Printer, config: Any?) {
        val barcode = config as? Map<*, *> ?: return
        val data = barcode["data"]?.toString()?.takeIf { it.isNotBlank() } ?: return
        val height = (barcode["height"] as? Number)?.toInt() ?: DEFAULT_BARCODE_HEIGHT
        val width = ((barcode["width"] as? Number)?.toInt())?.coerceIn(2, 6) ?: DEFAULT_BARCODE_WIDTH
        try {
            printer.addBarcode(
                data,
                CommonPrinter.BARCODE_CODE128,
                CommonPrinter.HRI_BELOW,
                CommonPrinter.FONT_A,
                width,
                height,
            )
            printer.addFeedLine(1)
        } catch (error: Epos2Exception) {
            Log.w(TAG, "Unable to add barcode", error)
        }
    }

    private fun resolveModel(name: String): Int {
        return findStaticField(Printer::class.java, name) ?: Printer.TM_M30
    }

    private fun resolveLang(name: String): Int {
        return findStaticField(CommonPrinter::class.java, name) ?: CommonPrinter.MODEL_ANK
    }

    private fun resolveCutType(name: String): Int {
        return findStaticField(CommonPrinter::class.java, name) ?: CommonPrinter.CUT_FEED
    }

    private fun findStaticField(clazz: Class<*>, name: String): Int? {
        return runCatching {
            val field = clazz.getField(name)
            field.getInt(null)
        }.getOrNull()
    }

    private fun describeEposError(error: Epos2Exception): String {
        return when (error.errorStatus) {
            Epos2Exception.ERR_PARAM -> "Invalid parameters supplied"
            Epos2Exception.ERR_CONNECT -> "Failed to connect to printer"
            Epos2Exception.ERR_TIMEOUT -> "Printer connection timed out"
            Epos2Exception.ERR_MEMORY -> "Printer out of memory"
            Epos2Exception.ERR_ILLEGAL -> "Illegal printer command"
            Epos2Exception.ERR_PROCESSING -> "Printer is processing another job"
            Epos2Exception.ERR_NOT_FOUND -> "Printer not found"
            Epos2Exception.ERR_IN_USE -> "Printer is currently in use"
            Epos2Exception.ERR_DISCONNECT -> "Printer disconnected"
            Epos2Exception.ERR_ALREADY_OPENED -> "Printer connection already open"
            Epos2Exception.ERR_ALREADY_USED -> "Printer instance already used"
            Epos2Exception.ERR_BOX_COUNT_OVER -> "Too many print jobs queued"
            Epos2Exception.ERR_BOX_CLIENT_OVER -> "Printer client limit exceeded"
            Epos2Exception.ERR_UNSUPPORTED -> "Printer command unsupported"
            Epos2Exception.ERR_FAILURE -> "Printer reported failure"
            Epos2Exception.ERR_SEQUENCE -> "Printer command sequence error"
            else -> "Printer error ${error.errorStatus}"
        }
    }

    private fun checkPrinterStatus(status: PrinterStatusInfo): String? {
        if (status.online == CommonPrinter.FALSE) {
            return "Printer is offline"
        }
        if (status.connection == CommonPrinter.FALSE) {
            return "Printer is not connected"
        }
        if (status.coverOpen == CommonPrinter.TRUE) {
            return "Printer cover is open"
        }
        if (status.paper == CommonPrinter.PAPER_EMPTY) {
            return "Printer is out of paper"
        }
        if (status.paper == CommonPrinter.PAPER_NEAR_END) {
            return "Printer paper is near end"
        }
        if (status.errorStatus != 0) {
            return "Printer error status ${status.errorStatus}"
        }
        return null
    }

    private fun parseIsoDate(raw: String): Date? {
        val patterns = arrayOf(
            "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'",
            "yyyy-MM-dd'T'HH:mm:ss'Z'",
            "yyyy-MM-dd'T'HH:mm:ss.SSSXXX",
            "yyyy-MM-dd'T'HH:mm:ssXXX",
        )
        for (pattern in patterns) {
            val parser = SimpleDateFormat(pattern, Locale.US).apply {
                timeZone = TimeZone.getTimeZone("UTC")
            }
            try {
                return parser.parse(raw)
            } catch (_: Exception) {
                // Try next pattern
            }
        }
        return null
    }

    private fun formatLine(label: String, value: String, columns: Int): String {
        if (columns <= 0) {
            return value.replace('\n', ' ') + "\n"
        }

        val sanitizedValue = value.replace('\n', ' ').take(columns)
        val availableForLabel = (columns - sanitizedValue.length - 1).coerceAtLeast(0)
        if (availableForLabel == 0) {
            return sanitizedValue + "\n"
        }

        val rawLabel = label.replace('\n', ' ')
        val trimmedLabel = when {
            rawLabel.length <= availableForLabel -> rawLabel
            availableForLabel == 1 -> "…"
            else -> rawLabel.substring(0, availableForLabel - 1) + "…"
        }

        return String.format(Locale.UK, "%-${availableForLabel}s %s\n", trimmedLabel, sanitizedValue)
    }

    private enum class PaperSize(val itemColumns: Int) {
        MM58(32),
        MM80(48);

        companion object {
            private val DEFAULT = MM80

            fun fromConfig(raw: Any?): PaperSize {
                val text = raw?.toString()?.trim()
                if (text.isNullOrEmpty()) {
                    return DEFAULT
                }

                val upper = text.uppercase(Locale.US)
                val digits = upper.filter { it.isDigit() }
                return when {
                    digits == "57" || digits == "58" -> MM58
                    digits == "80" || digits == "79" -> MM80
                    upper.contains("2IN") -> MM58
                    upper.contains("3IN") -> MM80
                    upper.contains("58") || upper.contains("57") -> MM58
                    upper.contains("80") || upper.contains("79") -> MM80
                    else -> DEFAULT
                }
            }
        }
    }

    private fun success(copies: Int): Map<String, Any?> = mapOf(
        "ok" to true,
        "copiesPrinted" to copies,
    )

    private fun failure(message: String): Map<String, Any?> = mapOf(
        "ok" to false,
        "error" to message,
    )

    private class PrinterStatusException(message: String) : Exception(message)

    private fun Printer.use(block: (Printer) -> Unit) {
        try {
            block(this)
        } finally {
            try {
                clearCommandBuffer()
            } catch (_: Throwable) {
            }
            setReceiveEventListener(null)
            try {
                disconnect()
            } catch (_: Throwable) {
            }
        }
    }

    companion object {
        private const val TAG = "EpsonDirectPrinter"
        private const val METHOD_IS_AVAILABLE = "isAvailable"
        private const val METHOD_PRINT_DIRECT = "printDirect"
        private const val DEFAULT_MODEL = "TM_M30"
        private const val DEFAULT_LANG = "MODEL_ANK"
        private const val DEFAULT_CUT = "CUT_FEED"
        private const val DEFAULT_TIMEOUT = 10000
        private const val DEFAULT_QR_SIZE = 6
        private const val DEFAULT_BARCODE_HEIGHT = 80
        private const val DEFAULT_BARCODE_WIDTH = 3
        private const val DEFAULT_CURRENCY = "GBP"

        fun registerWith(messenger: BinaryMessenger, context: Context) {
            val channel = MethodChannel(messenger, CHANNEL_NAME)
            val plugin = EpsonDirectPrinterPlugin(context.applicationContext)
            channel.setMethodCallHandler(plugin)
        }

        private const val CHANNEL_NAME = "leson.pos/printer"
    }
}
