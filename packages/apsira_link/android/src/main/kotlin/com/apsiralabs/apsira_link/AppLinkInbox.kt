package com.apsiralabs.apsira_link

import android.content.Context
import java.io.File
import java.util.concurrent.CopyOnWriteArraySet
import org.json.JSONException
import org.json.JSONObject

// Where a restore offer from APSIRA waits for the app (contract app-link.md
// §5.4, D-034; K2-02d), written from the contract. AppLinkProvider keeps the
// latest offer in noBackupFilesDir/apsira_link/restore_offer.json, written to
// a .tmp file and renamed over the old one, so a reader sees a whole offer or
// none; then it tells every attached engine (ApsiraLinkPlugin's requests
// channel). The app's Dart takes it (reads and clears) at start, on resume
// and when told. Nothing is logged: the offer names a backup.
object AppLinkInbox {
    const val DIR = "apsira_link"
    const val FILE = "restore_offer.json"

    // The offer's keys: restore_offer's extras (contract §5.4).
    const val NAME = "name"
    const val SNAPSHOT = "snapshot"
    const val MADE_UTC = "made_utc"
    const val SIZE = "size"
    const val REASON = "reason"

    /** restore_offer's reasons. */
    val REASONS = setOf("user", "new_device")

    // An ISO 8601 instant in UTC, as Dart's DateTime.toIso8601String writes it.
    private val UTC = Regex("\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}(\\.\\d{1,9})?Z")

    private val listeners = CopyOnWriteArraySet<() -> Unit>()

    /** An attached engine, told when an offer arrives. */
    fun addListener(listener: () -> Unit) {
        listeners += listener
    }

    fun removeListener(listener: () -> Unit) {
        listeners -= listener
    }

    /**
     * The offer [values] holds, in its wire types (size a Long); null when any
     * field is missing, of the wrong type or out of range.
     */
    fun offer(values: (String) -> Any?): Map<String, Any>? {
        val name = values(NAME) as? String
        val snapshot = values(SNAPSHOT) as? String
        val made = values(MADE_UTC) as? String
        val size = when (val raw = values(SIZE)) {
            is Long -> raw
            is Int -> raw.toLong()
            else -> null
        }
        val reason = values(REASON) as? String
        if (name.isNullOrEmpty() || snapshot.isNullOrEmpty()) return null
        if (made == null || !UTC.matches(made)) return null
        if (size == null || size < 0) return null
        if (reason !in REASONS) return null
        return mapOf(NAME to name, SNAPSHOT to snapshot, MADE_UTC to made, SIZE to size, REASON to reason!!)
    }

    /** Keeps [offer] in place of any older one, then tells every engine; false when it could not be written. */
    fun put(context: Context, offer: Map<String, Any>): Boolean {
        val written = synchronized(this) {
            try {
                val file = file(context)
                file.parentFile?.mkdirs()
                val tmp = File(file.path + ".tmp")
                tmp.writeText(JSONObject(offer).toString())
                if (!tmp.renameTo(file)) {
                    tmp.delete()
                    false
                } else {
                    true
                }
            } catch (e: Exception) {
                false
            }
        }
        if (written) listeners.forEach { it() }
        return written
    }

    /** The waiting offer, cleared; null when there is none or it is not a whole offer. */
    fun take(context: Context): Map<String, Any>? = synchronized(this) {
        val file = file(context)
        if (!file.exists()) return null
        val json = try {
            JSONObject(file.readText())
        } catch (e: JSONException) {
            null
        } catch (e: java.io.IOException) {
            null
        }
        file.delete()
        json ?: return null
        offer { key -> json.opt(key)?.let { if (key == SIZE && it is Int) it.toLong() else it } }
    }

    private fun file(context: Context) = File(context.noBackupFilesDir, "$DIR/$FILE")
}
