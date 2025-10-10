package com.epson.epos2

open class Epos2Exception(
    val errorStatus: Int = ERR_ILLEGAL,
    override val message: String? = null,
) : Exception(message) {
    companion object {
        const val ERR_TIMEOUT = 1
        const val ERR_CONNECT = 2
        const val ERR_MEMORY = 3
        const val ERR_ILLEGAL = 4
        const val ERR_OFF_LINE = 5
    }
}
