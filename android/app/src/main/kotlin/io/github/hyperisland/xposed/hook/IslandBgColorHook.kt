package io.github.hyperisland.xposed.hook

import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import de.robv.android.xposed.IXposedHookLoadPackage
import de.robv.android.xposed.XC_MethodHook
import de.robv.android.xposed.XposedBridge
import de.robv.android.xposed.XposedHelpers
import de.robv.android.xposed.callbacks.XC_LoadPackage

/**
 * Hook 灵动岛插件（miui.systemui.plugin）中的背景填充色。
 *
 * ## 工作原理
 *
 * [DynamicIslandBackgroundView] 有一个 `drawable` 字段，由
 * [updateMedianLuma] 和 [updateDarkLightMode] 通过 setDrawable() 设置后在 onDraw 绘制。
 * 本 Hook 拦截 [DynamicIslandBackgroundView.setDrawable]，
 * 在传入的 drawable（GradientDrawable）上额外调用 setColor() 覆盖填充色。
 */
class IslandBgColorHook : IXposedHookLoadPackage {

    companion object {
        private const val COLOR_NOT_SET = Int.MIN_VALUE
        private const val PLUGIN_PKG = "com.android.systemui"
        private const val BG_VIEW_CLASS =
            "miui.systemui.dynamicisland.DynamicIslandBackgroundView"

        @Volatile private var cachedBgColor: Int? = null
        @Volatile private var observerRegistered = false

        fun ensureObserver(context: android.content.Context) {
            if (observerRegistered) return
            val uri = android.net.Uri.parse("content://io.github.hyperisland.settings/")
            context.contentResolver.registerContentObserver(
                uri, true,
                object : android.database.ContentObserver(
                    android.os.Handler(android.os.Looper.getMainLooper())
                ) {
                    override fun onChange(selfChange: Boolean) {
                        cachedBgColor = null
                    }
                }
            )
            observerRegistered = true
        }

        private fun resolveBgColor(context: android.content.Context): Int {
            cachedBgColor?.let { return it }
            val result = try {
                val uri = android.net.Uri.parse(
                    "content://io.github.hyperisland.settings/pref_island_bg_color"
                )
                val raw = context.contentResolver.query(uri, null, null, null, null)
                    ?.use { if (it.moveToFirst()) it.getString(0) else "" } ?: ""
                if (raw.isEmpty()) COLOR_NOT_SET
                else parseHexColor(raw) ?: COLOR_NOT_SET
            } catch (_: Exception) { COLOR_NOT_SET }
            cachedBgColor = result
            return result
        }

        private fun parseHexColor(hex: String): Int? {
            return try {
                val clean = hex.trimStart('#')
                when (clean.length) {
                    6 -> Color.parseColor("#$clean")
                    8 -> java.lang.Long.parseLong(clean, 16).toInt()
                    else -> null
                }
            } catch (_: Exception) { null }
        }
    }

    override fun handleLoadPackage(lpparam: XC_LoadPackage.LoadPackageParam) {
        if (lpparam.packageName != PLUGIN_PKG) return
        XposedBridge.log("HyperIsland[IslandBgColorHook]: initializing")

        try {
            val bgViewClass = lpparam.classLoader.loadClass(BG_VIEW_CLASS)

            // Hook DynamicIslandBackgroundView.setDrawable(Drawable)
            // updateMedianLuma/updateDarkLightMode 都通过此方法设置背景 drawable
            // 在 beforeHookedMethod 中拦截并修改 drawable 的填充色
            XposedHelpers.findAndHookMethod(
                bgViewClass,
                "setDrawable",
                android.graphics.drawable.Drawable::class.java,
                object : XC_MethodHook() {
                    override fun beforeHookedMethod(param: MethodHookParam) {
                        try {
                            val drawable = param.args[0] as? GradientDrawable ?: return
                            val view = param.thisObject as android.view.View
                            ensureObserver(view.context)
                            val color = resolveBgColor(view.context)
                            if (color != COLOR_NOT_SET) {
                                drawable.setColor(color)
                                XposedBridge.log(
                                    "HyperIsland[IslandBgColorHook]: setDrawable intercepted, fill=" +
                                    String.format("#%08X", color)
                                )
                            }
                        } catch (_: Exception) {}
                    }
                }
            )
            XposedBridge.log("HyperIsland[IslandBgColorHook]: hooked setDrawable")

        } catch (e: Exception) {
            XposedBridge.log("HyperIsland[IslandBgColorHook]: init error: ${e.message}")
        }
    }
}
