package com.epson.epos2.printer

class PrinterStatusInfo {
    var connection: Int = Printer.TRUE
    var online: Int = Printer.TRUE
    var coverOpen: Int = Printer.FALSE
    var paper: Int = Printer.PAPER_OK
    var autoRecoverError: Int = Printer.ERROR_OK
    var errorStatus: Int = Printer.NO_ERROR
}
