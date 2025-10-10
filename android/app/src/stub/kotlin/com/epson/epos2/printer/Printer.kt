package com.epson.epos2.printer

import android.content.Context

class Printer(model: Int, lang: Int, context: Context) {
    val status: PrinterStatusInfo = PrinterStatusInfo()

    fun connect(target: String, timeout: Int) {}
    fun beginTransaction() {}
    fun endTransaction() {}
    fun disconnect() {}
    fun clearCommandBuffer() {}
    fun sendData(param: Int) {}
    fun addTextAlign(align: Int) {}
    fun addText(text: String) {}
    fun addFeedLine(line: Int) {}
    fun addCut(type: Int) {}
    fun addPulse(drawer: Int, time: Int) {}
    fun setReceiveEventListener(listener: Any?) {}

    companion object {
        const val ALIGN_LEFT = 0
        const val ALIGN_CENTER = 1
        const val ALIGN_RIGHT = 2

        const val CUT_FEED = 0
        const val CUT_NO_FEED = 1

        const val DRAWER_2PIN = 0
        const val PULSE_100 = 100

        const val PARAM_DEFAULT = 0

        const val TRUE = 1
        const val FALSE = 0

        const val PAPER_OK = 0
        const val PAPER_NEAR_END = 1
        const val PAPER_EMPTY = 2

        const val ERROR_OK = 0
        const val NO_ERROR = 0

        const val AUTO_RECOVER_ERR_HEAD_OVERHEAT = 1
        const val AUTO_RECOVER_ERR_COVER_OPEN = 2
        const val AUTO_RECOVER_ERR_PAPER_JAM = 3
        const val AUTO_RECOVER_ERR_PAPER_END = 4

        const val TM_M30 = 0
        const val TM_M30II = 1
        const val TM_M30III = 2

        const val MODEL_ANK = 0
        const val MODEL_JAPANESE = 1
        const val MODEL_CHINESE = 2
    }
}
