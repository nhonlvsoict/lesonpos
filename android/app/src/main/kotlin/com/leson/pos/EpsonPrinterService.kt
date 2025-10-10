package com.leson.pos

import android.content.Context
import com.epson.epos2.Epos2Exception
import com.epson.epos2.printer.Printer
import com.epson.epos2.printer.PrinterStatusInfo
import java.time.OffsetDateTime
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale

class EpsonPrinterService(private val context: Context) {

    fun printReceipt(payload: Map<*, *>): Map<String, Any?> {
        val config = payload["config"] as? Map<*, *>
            ?: return failure("Missing printer config")
        val receipt = payload["receipt"] as? Map<*, *>
            ?: return failure("Missing receipt data")
        val store = payload["store"] as? Map<*, *> ?: emptyMap<String, Any?>()
        val options = payload["printOptions"] as? Map<*, *> ?: emptyMap<String, Any?>()
        val copies = (payload["copies"] as? Number)?.toInt()?.coerceAtLeast(1) ?: 1

        val target = config["target"]?.toString()?.takeIf { it.isNotBlank() }
            ?: return failure("Printer target not provided")
        val timeout = (config["timeout"] as? Number)?.toInt() ?: 10000
        val model = config["model"]?.toString() ?: "TM_M30"
        val lang = config["lang"]?.toString() ?: "MODEL_ANK"

        val printer = try {
            Printer(parseModel(model), parseLanguage(lang), context)
        } catch (e: Exception) {
            return failure("Failed to initialise printer: ${e.message}")
        }

        try {
            printer.connect(target, timeout)
            printer.beginTransaction()

            val statusMessage = interpretStatus(printer.status)
            if (statusMessage != null) {
                return failure(statusMessage)
            }

            repeat(copies) {
                composeReceipt(printer, store, receipt)
                applyOptions(printer, options)
                printer.sendData(Printer.PARAM_DEFAULT)
                printer.clearCommandBuffer()
            }
        } catch (e: Epos2Exception) {
            return failure(describeEposError(e))
        } catch (e: Exception) {
            return failure(e.message ?: "Unknown printer error")
        } finally {
            try {
                printer.endTransaction()
            } catch (_: Exception) {
            }
            try {
                printer.disconnect()
            } catch (_: Exception) {
            }
            try {
                printer.clearCommandBuffer()
            } catch (_: Exception) {
            }
            printer.setReceiveEventListener(null)
        }

        return mapOf("ok" to true)
    }

    private fun composeReceipt(
        printer: Printer,
        store: Map<*, *>,
        receipt: Map<*, *>,
    ) {
        val currency = receipt["currency"]?.toString() ?: "GBP"

        val name = store["name"]?.toString()?.takeIf { it.isNotBlank() }
        val address = store["address"]?.toString()?.takeIf { it.isNotBlank() }
        val phone = store["phone"]?.toString()?.takeIf { it.isNotBlank() }

        printer.addTextAlign(Printer.ALIGN_CENTER)
        if (name != null) {
            printer.addText("$name\n")
        }
        if (address != null) {
            printer.addText("$address\n")
        }
        if (phone != null) {
            printer.addText("$phone\n")
        }

        printer.addFeedLine(1)
        printer.addTextAlign(Printer.ALIGN_LEFT)

        val createdAt = receipt["createdAt"]?.toString()
        val formattedDate = createdAt?.let { formatDate(it) }
        val table = receipt["table"]?.toString()?.takeIf { it.isNotBlank() }
        val server = receipt["server"]?.toString()?.takeIf { it.isNotBlank() }
        val orderId = receipt["orderId"]?.toString()?.takeIf { it.isNotBlank() }
        val note = receipt["note"]?.toString()?.takeIf { it.isNotBlank() }

        if (formattedDate != null) {
            printer.addText("Date: $formattedDate\n")
        }
        if (orderId != null) {
            printer.addText("Order: $orderId\n")
        }
        if (table != null) {
            printer.addText("Table: $table\n")
        }
        if (server != null) {
            printer.addText("Server: $server\n")
        }
        if (note != null) {
            printer.addText("Note: $note\n")
        }

        printer.addFeedLine(1)

        val items = (receipt["items"] as? List<*>)
            ?.mapNotNull { it as? Map<*, *> }
            ?: emptyList()

        val grouped = linkedMapOf<String, MutableList<Map<*, *>>>()
        for (item in items) {
            val category = item["category"]?.toString() ?: "Other"
            grouped.getOrPut(category) { mutableListOf() }.add(item)
        }

        for ((category, groupItems) in grouped) {
            printer.addTextAlign(Printer.ALIGN_LEFT)
            printer.addText("${category.uppercase(Locale.getDefault())}\n")
            for (item in groupItems) {
                val qty = (item["qty"] as? Number)?.toInt() ?: 0
                val nameValue = item["name"]?.toString() ?: ""
                val unitPrice = (item["unitPricePence"] as? Number)?.toInt() ?: 0
                val total = unitPrice * qty
                printer.addText(buildItemLine(qty, nameValue, total, currency) + "\n")
                val noteValue = item["note"]?.toString()?.takeIf { it.isNotBlank() }
                if (noteValue != null) {
                    printer.addText("  - $noteValue\n")
                }
            }
            printer.addFeedLine(1)
        }

        val subTotal = (receipt["subTotal"] as? Number)?.toInt() ?: 0
        val discount = (receipt["discount"] as? Number)?.toInt() ?: 0
        val serviceCharge = (receipt["serviceCharge"] as? Number)?.toInt() ?: 0
        val tax = (receipt["tax"] as? Number)?.toInt() ?: 0
        val total = (receipt["total"] as? Number)?.toInt() ?: subTotal

        printer.addText(drawTotalLine("Subtotal", subTotal, currency) + "\n")
        if (discount != 0) {
            printer.addText(drawTotalLine("Discount", -discount, currency) + "\n")
        }
        if (serviceCharge != 0) {
            printer.addText(drawTotalLine("Service", serviceCharge, currency) + "\n")
        }
        if (tax != 0) {
            printer.addText(drawTotalLine("Tax", tax, currency) + "\n")
        }
        printer.addText(drawTotalLine("Total", total, currency) + "\n")

        printer.addFeedLine(1)
        val footer = (receipt["footerLines"] as? List<*>)?.mapNotNull { it?.toString() } ?: emptyList()
        if (footer.isNotEmpty()) {
            printer.addTextAlign(Printer.ALIGN_CENTER)
            for (line in footer) {
                printer.addText("$line\n")
            }
            printer.addFeedLine(1)
        }
    }

    private fun applyOptions(printer: Printer, options: Map<*, *>) {
        val cut = options["cutType"]?.toString()?.let { parseCutType(it) } ?: Printer.CUT_FEED
        printer.addCut(cut)
        val openDrawer = when (val value = options["openDrawer"]) {
            is Boolean -> value
            is Number -> value.toInt() != 0
            else -> false
        }
        if (openDrawer) {
            printer.addPulse(Printer.DRAWER_2PIN, Printer.PULSE_100)
        }
    }

    private fun parseModel(model: String): Int = when (model.uppercase(Locale.getDefault())) {
        "TM_M30II" -> Printer.TM_M30II
        "TM_M30III" -> Printer.TM_M30III
        "TM_M30" -> Printer.TM_M30
        else -> Printer.TM_M30
    }

    private fun parseLanguage(lang: String): Int = when (lang.uppercase(Locale.getDefault())) {
        "MODEL_ANK" -> Printer.MODEL_ANK
        "MODEL_JAPANESE" -> Printer.MODEL_JAPANESE
        "MODEL_CHINESE" -> Printer.MODEL_CHINESE
        else -> Printer.MODEL_ANK
    }

    private fun parseCutType(cutType: String): Int = when (cutType.uppercase(Locale.getDefault())) {
        "CUT_NO_FEED" -> Printer.CUT_NO_FEED
        else -> Printer.CUT_FEED
    }

    private fun buildItemLine(qty: Int, name: String, total: Int, currency: String): String {
        val label = "$qty x $name"
        val price = formatMoney(total, currency)
        val maxChars = 42
        val padding = (maxChars - label.length - price.length).coerceAtLeast(1)
        return if (label.length + price.length >= maxChars) {
            "$label\n${" ".repeat(2)}$price"
        } else {
            label + " ".repeat(padding) + price
        }
    }

    private fun drawTotalLine(label: String, amount: Int, currency: String): String {
        val value = formatMoney(amount, currency)
        return String.format(Locale.getDefault(), "%-12s %10s", label.uppercase(Locale.getDefault()), value)
    }

    private fun formatMoney(amountInMinor: Int, currency: String): String {
        val amount = amountInMinor / 100.0
        val symbol = when (currency.uppercase(Locale.getDefault())) {
            "GBP" -> "£"
            "USD" -> "\$"
            "EUR" -> "€"
            else -> ""
        }
        return String.format(Locale.getDefault(), "%s%.2f", symbol, amount)
    }

    private fun formatDate(raw: String): String {
        return try {
            val date = OffsetDateTime.parse(raw)
            val zoned = date.atZoneSameInstant(ZoneId.systemDefault())
            DateTimeFormatter.ofPattern("dd/MMM/yyyy HH:mm", Locale.UK).format(zoned)
        } catch (_: Exception) {
            raw
        }
    }

    private fun interpretStatus(status: PrinterStatusInfo): String? {
        return when {
            status.connection == Printer.FALSE || status.online == Printer.FALSE -> "Printer is offline"
            status.coverOpen == Printer.TRUE -> "Printer cover is open"
            status.paper == Printer.PAPER_EMPTY -> "Printer is out of paper"
            status.paper == Printer.PAPER_NEAR_END -> "Printer paper is nearly empty"
            status.autoRecoverError != Printer.ERROR_OK -> mapAutoRecoverError(status.autoRecoverError)
            status.errorStatus != Printer.NO_ERROR -> "Printer error occurred"
            else -> null
        }
    }

    private fun mapAutoRecoverError(error: Int): String {
        return when (error) {
            Printer.AUTO_RECOVER_ERR_HEAD_OVERHEAT -> "Printer head overheated"
            Printer.AUTO_RECOVER_ERR_COVER_OPEN -> "Printer cover is open"
            Printer.AUTO_RECOVER_ERR_PAPER_JAM -> "Paper jam detected"
            Printer.AUTO_RECOVER_ERR_PAPER_END -> "Printer is out of paper"
            else -> "Printer requires recovery"
        }
    }

    private fun describeEposError(e: Epos2Exception): String {
        return when (e.errorStatus) {
            Epos2Exception.ERR_TIMEOUT -> "Connection to printer timed out"
            Epos2Exception.ERR_CONNECT -> "Could not connect to printer"
            Epos2Exception.ERR_MEMORY -> "Printer memory error"
            Epos2Exception.ERR_ILLEGAL -> "Illegal printer state"
            Epos2Exception.ERR_OFF_LINE -> "Printer is offline"
            else -> e.message ?: "Unknown printer error"
        }
    }

    private fun failure(message: String): Map<String, Any?> = mapOf(
        "ok" to false,
        "error" to message,
    )
}
