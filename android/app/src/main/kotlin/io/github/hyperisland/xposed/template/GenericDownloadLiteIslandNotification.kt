package io.github.hyperisland.xposed.templates

import android.app.Notification
import android.content.Context
import android.graphics.drawable.Icon
import android.os.Build
import android.os.Bundle
import io.github.hyperisland.R
import io.github.hyperisland.xposed.IslandTemplate
import io.github.hyperisland.xposed.NotifData
import io.github.hyperisland.xposed.moduleContext
import io.github.hyperisland.xposed.toRounded
import de.robv.android.xposed.XposedBridge
import io.github.d4viddf.hyperisland_kit.HyperAction
import io.github.d4viddf.hyperisland_kit.HyperIslandNotification
import io.github.d4viddf.hyperisland_kit.HyperPicture
import io.github.d4viddf.hyperisland_kit.models.CircularProgressInfo
import io.github.d4viddf.hyperisland_kit.models.ImageTextInfoLeft
import io.github.d4viddf.hyperisland_kit.models.PicInfo
import io.github.d4viddf.hyperisland_kit.models.ProgressTextInfo
import io.github.d4viddf.hyperisland_kit.models.TextInfo

/**
 * 下载 Lite 灵动岛通知构建器。
 * 基于 GenericProgressIslandNotification，摘要态仅显示图标与环形进度，无任何文字。
 * 焦点通知、按钮与大版本保持一致。
 */
object DownloadLiteIslandNotification : IslandTemplate {

    const val TEMPLATE_ID = "download_lite"

    override val id = TEMPLATE_ID

    override fun inject(context: Context, extras: Bundle, data: NotifData) = inject(
        context         = context,
        extras          = extras,
        title           = data.title,
        subtitle        = data.subtitle,
        progress        = data.progress,
        actions         = data.actions,
        notifIcon       = data.notifIcon,
        largeIcon       = data.largeIcon,
        appIconRaw      = data.appIconRaw,
        iconMode        = data.iconMode,
        focusIconMode   = data.focusIconMode,
        focusNotif      = data.focusNotif,
        firstFloat      = data.firstFloat,
        enableFloatMode = data.enableFloatMode,
        timeoutSecs     = data.islandTimeout,
    )

    private fun inject(
        context: Context,
        extras: Bundle,
        title: String,
        subtitle: String,
        progress: Int,
        actions: List<Notification.Action>,
        notifIcon: Icon?,
        largeIcon: Icon?,
        appIconRaw: Icon?,
        iconMode: String,
        focusIconMode: String,
        focusNotif: String,
        firstFloat: String,
        enableFloatMode: String,
        timeoutSecs: Int,
    ) {
        try {
            val isComplete = progress >= 100
            val isPaused   = !isComplete && (
                "$title $subtitle ".let {
                    it.contains("暂停") || it.contains("已暂停") || it.contains("暂停中") ||
                    it.contains("paused", ignoreCase = true)
                }
            )

            val iconRes   = if (isComplete) android.R.drawable.stat_sys_download_done
                            else            android.R.drawable.stat_sys_download
            val tintColor = when {
                isComplete -> 0xFF4CAF50.toInt()  // 绿
                isPaused   -> 0xFFFF9800.toInt()  // 橙
                else       -> 0xFF2196F3.toInt()  // 蓝
            }
            val fallbackIcon = Icon.createWithResource(context, iconRes).apply { setTint(tintColor) }

            // 大岛区域图标
            val displayIcon = when (iconMode) {
                "notif_small" -> notifIcon ?: fallbackIcon
                "notif_large" -> largeIcon ?: notifIcon ?: fallbackIcon
                "app_icon"    -> appIconRaw ?: fallbackIcon
                else          -> notifIcon ?: largeIcon ?: fallbackIcon
            }.toRounded(context)

            // 焦点图标
            val focusDisplayIcon = when (focusIconMode) {
                "notif_small" -> notifIcon ?: appIconRaw ?: fallbackIcon
                "notif_large" -> largeIcon ?: appIconRaw ?: notifIcon ?: fallbackIcon
                "app_icon"    -> appIconRaw ?: fallbackIcon
                else          -> largeIcon ?: appIconRaw ?: notifIcon ?: fallbackIcon
            }.toRounded(context)

            val resolvedFirstFloat  = firstFloat      == "on"
            val resolvedEnableFloat = enableFloatMode == "on"
            val showNotification    = focusNotif != "off"
            val displayContent      = subtitle.ifEmpty { title }

            val builder = HyperIslandNotification.Builder(context, TEMPLATE_ID, title)

            builder.addPicture(HyperPicture("key_dl_lite_icon", displayIcon))
            builder.addPicture(HyperPicture("key_dl_lite_focus_icon", focusDisplayIcon))

            builder.setIconTextInfo(
                picKey  = "key_dl_lite_focus_icon",
                title   = title,
                content = displayContent,
            )

            builder.setIslandFirstFloat(resolvedFirstFloat)
            builder.setEnableFloat(resolvedEnableFloat)
            builder.setShowNotification(showNotification)
            builder.setIslandConfig(timeout = timeoutSecs)

            // 摘要态：小岛带环形进度（下载中），否则仅图标
            if (!isComplete && progress > 0) {
                builder.setSmallIslandCircularProgress("key_dl_lite_icon", progress)
            } else {
                builder.setSmallIsland("key_dl_lite_icon")
            }

            // 大岛：左侧仅图标（无文字），右侧仅环形进度（无文字）
            if (!isComplete && !isPaused && progress > 0) {
                builder.setBigIslandInfo(
                    left = ImageTextInfoLeft(
                        type     = 1,
                        picInfo  = PicInfo(type = 1, pic = "key_dl_lite_icon"),
                        textInfo = TextInfo(title = ""),
                    ),
                    progressText = ProgressTextInfo(
                        progressInfo = CircularProgressInfo(progress = progress),
                        textInfo     = TextInfo(title = ""),
                    ),
                )
            } else {
                // 完成/暂停/等待：仅左侧图标
                builder.setBigIslandInfo(
                    left = ImageTextInfoLeft(
                        type     = 1,
                        picInfo  = PicInfo(type = 1, pic = "key_dl_lite_icon"),
                        textInfo = TextInfo(title = ""),
                    ),
                )
            }

            // 来自原通知的按钮（最多 2 个）
            val effectiveActions = actions.take(2)
            if (effectiveActions.isNotEmpty() && showNotification) {
                val hyperActions = effectiveActions.mapIndexed { index, action ->
                    HyperAction(
                        key              = "action_dl_lite_$index",
                        title            = action.title ?: "",
                        pendingIntent    = action.actionIntent,
                        actionIntentType = 2,
                    )
                }
                hyperActions.forEach { builder.addHiddenAction(it) }
                builder.setTextButtons(*hyperActions.toTypedArray())
            }

            val resourceBundle = builder.buildResourceBundle()
            extras.putAll(resourceBundle)
            flattenActionsToExtras(resourceBundle, extras)

            val wrapLongText = isWrapLongTextEnabled(context)
            val jsonParam = injectUpdatable(
                fixTextButtonJson(builder.buildJsonParam(), wrapLongText), !isComplete && !isPaused
            )
            extras.putString("miui.focus.param", jsonParam)

            XposedBridge.log("HyperIsland[DownloadLite]: Island injected — $title (${progress}%) buttons=${actions.size}")

        } catch (e: Exception) {
            XposedBridge.log("HyperIsland[DownloadLite]: Island injection error: ${e.message}")
        }
    }

    private fun fixTextButtonJson(jsonParam: String, wrapLongText: Boolean = false): String {
        return try {
            val json = org.json.JSONObject(jsonParam)
            val pv2  = json.optJSONObject("param_v2") ?: return jsonParam
            val btns = pv2.optJSONArray("textButton")
            if (btns != null) {
                for (i in 0 until btns.length()) {
                    val btn = btns.getJSONObject(i)
                    val key = btn.optString("actionIntent").takeIf { it.isNotEmpty() } ?: continue
                    btn.put("action", key)
                    btn.remove("actionIntent")
                    btn.remove("actionIntentType")
                }
            }

            if (wrapLongText) {
                val iconTextInfo = pv2.optJSONObject("iconTextInfo")
                if (iconTextInfo != null) {
                    val content = iconTextInfo.optString("content", "")
                    if (content.isNotEmpty()) {
                        var visualLen = 0
                        var splitIdx = -1
                        for (i in content.indices) {
                            val c = content[i]
                            visualLen += if (c.code > 255) 2 else 1
                            if (visualLen >= 36 && splitIdx == -1) {
                                splitIdx = i + 1
                            }
                        }
                        if (splitIdx != -1 && splitIdx < content.length) {
                            val subContent = content.substring(splitIdx)
                            val isUseless = subContent.all { it == '.' || it == '…' || it.isWhitespace() }
                            if (!isUseless) {
                                val coverInfo = org.json.JSONObject()
                                val animIcon = iconTextInfo.optJSONObject("animIconInfo")
                                if (animIcon != null) {
                                    coverInfo.put("picCover", animIcon.optString("src", ""))
                                }
                                coverInfo.put("title", iconTextInfo.optString("title", ""))
                                coverInfo.put("content", content.substring(0, splitIdx))
                                coverInfo.put("subContent", subContent)
                                pv2.remove("iconTextInfo")
                                pv2.put("coverInfo", coverInfo)
                            }
                        }
                    }
                }
            }

            json.toString()
        } catch (_: Exception) { jsonParam }
    }

    private fun injectUpdatable(jsonParam: String, updatable: Boolean): String {
        return try {
            val json = org.json.JSONObject(jsonParam)
            val pv2  = json.optJSONObject("param_v2") ?: org.json.JSONObject()
            pv2.put("updatable", updatable)
            json.put("param_v2", pv2)
            json.toString()
        } catch (_: Exception) { jsonParam }
    }

    private fun isWrapLongTextEnabled(context: Context): Boolean {
        return try {
            val uri = android.net.Uri.parse("content://io.github.hyperisland.settings/pref_wrap_long_text")
            context.contentResolver.query(uri, null, null, null, null)
                ?.use { if (it.moveToFirst()) it.getInt(0) != 0 else false } ?: false
        } catch (_: Exception) {
            false
        }
    }

    private fun flattenActionsToExtras(resourceBundle: Bundle, extras: Bundle) {
        val nested = resourceBundle.getBundle("miui.focus.actions") ?: return
        for (key in nested.keySet()) {
            val action: Notification.Action? = if (Build.VERSION.SDK_INT >= 33)
                nested.getParcelable(key, Notification.Action::class.java)
            else
                @Suppress("DEPRECATION") nested.getParcelable(key)
            if (action != null) extras.putParcelable(key, action)
        }
    }
}
