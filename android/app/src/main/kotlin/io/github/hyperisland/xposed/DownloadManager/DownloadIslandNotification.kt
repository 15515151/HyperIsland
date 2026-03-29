package io.github.hyperisland.xposed.templates

import android.app.Notification
import android.content.Context
import android.graphics.drawable.Icon
import io.github.hyperisland.xposed.InProcessController
import io.github.hyperisland.xposed.log
import io.github.hyperisland.xposed.logError

object DownloadIslandNotification {

    private const val TAG = "HyperIsland[Download]"

    fun inject(
        context: Context,
        notif: Notification,
        downloadId: Long,
        isMultiFile: Boolean,
        isComplete: Boolean,
        isWaiting: Boolean,
        isPaused: Boolean = false,
    ) {
        try {
            if (isComplete || isWaiting) {
                notif.actions = emptyArray()
                return
            }

            val primaryIntent = when {
                isPaused && isMultiFile -> InProcessController.resumeAllIntent(context)
                isPaused               -> InProcessController.resumeIntent(context, downloadId)
                isMultiFile            -> InProcessController.pauseAllIntent(context)
                else                   -> InProcessController.pauseIntent(context, downloadId)
            }
            val cancelIntent = if (isMultiFile) InProcessController.cancelAllIntent(context)
                               else             InProcessController.cancelIntent(context, downloadId)

            val primaryLabel = when {
                isPaused && isMultiFile -> "全部恢复"
                isPaused               -> "恢复"
                isMultiFile            -> "全部暂停"
                else                   -> "暂停"
            }
            val cancelLabel = if (isMultiFile) "全部取消" else "取消"

            notif.actions = arrayOf(
                Notification.Action.Builder(
                    Icon.createWithResource(context, android.R.drawable.ic_media_pause),
                    primaryLabel, primaryIntent
                ).build(),
                Notification.Action.Builder(
                    Icon.createWithResource(context, android.R.drawable.ic_delete),
                    cancelLabel, cancelIntent
                ).build()
            )

            log("$TAG: injected buttons — $primaryLabel / $cancelLabel")
        } catch (e: Exception) {
            logError("$TAG: inject error: ${e.message}")
        }
    }
}
