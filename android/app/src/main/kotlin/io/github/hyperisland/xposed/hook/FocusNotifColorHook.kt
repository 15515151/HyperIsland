package io.github.hyperisland.xposed.hook

import android.graphics.Color
import android.graphics.drawable.ColorDrawable
import android.view.View
import de.robv.android.xposed.IXposedHookLoadPackage
import de.robv.android.xposed.XC_MethodHook
import de.robv.android.xposed.XposedBridge
import de.robv.android.xposed.XposedHelpers
import de.robv.android.xposed.callbacks.XC_LoadPackage

/**
 * Hook SystemUI 中焦点通知（Focus Notification）的 FakeStatusView，
 * 实现用户自定义状态栏焦点通知背景颜色的功能。
 *
 * ## 工作原理
 *
 * HyperOS 在状态栏顶部用 [FakeStatusView]（AlphaOptimizedFrameLayout 子类）
 * 渲染焦点通知的摘要视图。该视图在 [FakeFocusNotifControllerImpl.updateFakeFocusNotifView]
 * 被刷新（图标、文字等），但背景色始终由系统 XML 主题决定，用户无法自定义。
 *
 * 本 Hook 在该方法返回后读取用户在 HyperIsland 应用中设置的颜色偏好，
 * 并通过 [View.setBackground] 动态覆盖背景，实现实时热加载。
 *
 * ## 热加载机制
 *
 * 通过与 [GenericProgressHook] / [MarqueeHook] 相同的 ContentObserver 模式，
 * 监听 SettingsProvider 变化，实时清除 [cachedBgColor] 缓存。
 *
 * ## 关闭开关时的行为
 *
 * 若用户清除颜色设置（恢复默认），[cachedBgColor] 变为 [COLOR_NOT_SET]，
 * Hook 会主动调用 [View.setBackground] 传入 null，还原系统默认背景。
 */
class FocusNotifColorHook : IXposedHookLoadPackage {

    companion object {
        /**
         * 哨兵值：表示缓存中的「无颜色」状态（用户未设置），与 null（缓存未初始化）区分。
         * 使用一个不可能是合法颜色的特殊整数值（Int.MIN_VALUE）。
         */
        private const val COLOR_NOT_SET = Int.MIN_VALUE

        /** 缓存的背景颜色 ARGB 整数；null 表示尚未读取，[COLOR_NOT_SET] 表示用户未设置。 */
        @Volatile private var cachedBgColor: Int? = null

        /** 确保 ContentObserver 只注册一次。 */
        @Volatile private var observerRegistered = false

        /**
         * 注册 ContentObserver，监听 SettingsProvider 任意变化以清除颜色缓存。
         * 与 [MarqueeHook.ensureObserver] 保持相同模式，幂等调用安全。
         */
        fun ensureObserver(context: android.content.Context) {
            if (observerRegistered) return
            val settingsUri = android.net.Uri.parse("content://io.github.hyperisland.settings/")
            context.contentResolver.registerContentObserver(
                settingsUri, true,
                object : android.database.ContentObserver(
                    android.os.Handler(android.os.Looper.getMainLooper())
                ) {
                    override fun onChange(selfChange: Boolean) {
                        // 失效缓存，下次 updateFakeFocusNotifView 时重新读取
                        cachedBgColor = null
                        XposedBridge.log("HyperIsland[FocusNotifColorHook]: settings changed, cache cleared")
                    }
                }
            )
            observerRegistered = true
            XposedBridge.log("HyperIsland[FocusNotifColorHook]: ContentObserver registered")
        }

        /**
         * 从缓存或 SettingsProvider 读取焦点通知背景色。
         *
         * @return 合法的 ARGB 整数，或 [COLOR_NOT_SET]（用户未设置 / 设置为空）。
         */
        private fun resolveBgColor(context: android.content.Context): Int {
            cachedBgColor?.let { return it }
            val result = try {
                val uri = android.net.Uri.parse(
                    "content://io.github.hyperisland.settings/pref_focus_notif_bg_color"
                )
                val raw = context.contentResolver.query(uri, null, null, null, null)
                    ?.use { if (it.moveToFirst()) it.getString(0) else "" } ?: ""
                if (raw.isEmpty()) {
                    COLOR_NOT_SET
                } else {
                    parseHexColor(raw) ?: COLOR_NOT_SET
                }
            } catch (_: Exception) { COLOR_NOT_SET }
            cachedBgColor = result
            return result
        }

        /**
         * 解析十六进制颜色字符串为 ARGB 整数。
         * 支持 #RRGGBB（自动补全 alpha=0xFF）和 #AARRGGBB 两种格式。
         * 格式不合法时返回 null。
         */
        private fun parseHexColor(hex: String): Int? {
            return try {
                val clean = hex.trimStart('#')
                when (clean.length) {
                    6 -> Color.parseColor("#$clean")                  // 补全不透明度
                    8 -> java.lang.Long.parseLong(clean, 16).toInt()   // 含 alpha
                    else -> null
                }
            } catch (_: Exception) { null }
        }

        /**
         * 将颜色应用到 [fakeStatusView] 的背景容器。
         *
         * FakeStatusView 通过 [getFakeStatusBackground()] 暴露内部的 AlphaOptimizedLinearLayout
         * （对应布局中 id 为 fake_status_background 的子 View），它是焦点通知的实际背景容器。
         *
         * - 颜色有效：设置 [ColorDrawable] 背景。
         * - 颜色为 [COLOR_NOT_SET]：调用 setBackground(null) 恢复系统默认背景。
         */
        fun applyColorToView(fakeStatusView: View, color: Int) {
            // 通过 getFakeStatusBackground() 获取背景子 View
            val bgView: View? = try {
                XposedHelpers.callMethod(fakeStatusView, "getFakeStatusBackground") as? View
            } catch (_: Exception) {
                // 回退到字段反射
                try {
                    XposedHelpers.getObjectField(fakeStatusView, "fakeStatusBackground") as? View
                } catch (_: Exception) { null }
            }
            val target = bgView ?: fakeStatusView

            if (color == COLOR_NOT_SET) {
                target.background = null
            } else {
                target.background = ColorDrawable(color)
            }
        }
    }

    // ─── IXposedHookLoadPackage ───────────────────────────────────────────────

    override fun handleLoadPackage(lpparam: XC_LoadPackage.LoadPackageParam) {
        if (lpparam.packageName != "com.android.systemui") return
        XposedBridge.log("HyperIsland[FocusNotifColorHook]: initializing")

        try {
            val controllerClass = lpparam.classLoader.loadClass(
                "com.android.systemui.statusbar.notification.policy.FakeFocusNotifControllerImpl"
            )

            // Hook updateFakeFocusNotifView(boolean)：该方法在焦点通知内容刷新时调用，
            // 在其执行完毕后覆写背景色，确保每次内容更新时颜色保持一致。
            val updateMethod = controllerClass.getDeclaredMethod(
                "updateFakeFocusNotifView", Boolean::class.javaPrimitiveType
            )
            XposedBridge.hookMethod(updateMethod, object : XC_MethodHook() {
                override fun afterHookedMethod(param: MethodHookParam) {
                    try {
                        val controller = param.thisObject
                        // 获取 FakeStatusView 实例（FEATURE_DYNAMIC_ISLAND 为 true 时该字段为 null）
                        val fakeStatusView = XposedHelpers.getObjectField(
                            controller, "fakeStatusView"
                        ) as? View

                        if (fakeStatusView == null) {
                            // 灵动岛模式下焦点通知视图不走 FakeStatusView，忽略
                            return
                        }

                        val context = fakeStatusView.context
                        ensureObserver(context)

                        val color = resolveBgColor(context)
                        applyColorToView(fakeStatusView, color)

                        XposedBridge.log(
                            "HyperIsland[FocusNotifColorHook]: applied bg color=" +
                            if (color == COLOR_NOT_SET) "system_default"
                            else String.format("#%08X", color)
                        )
                    } catch (e: Exception) {
                        XposedBridge.log("HyperIsland[FocusNotifColorHook]: apply error: ${e.message}")
                    }
                }
            })

            // 同时 hook onDarkChanged：当深色/浅色模式切换时该方法也会触发 updateFakeFocusNotifView，
            // 但部分场景下系统会直接修改背景，在此做二次保护。
            try {
                val onDarkChangedMethod = controllerClass.getDeclaredMethod(
                    "onDarkChanged",
                    java.util.ArrayList::class.java,
                    Float::class.javaPrimitiveType,
                    Int::class.javaPrimitiveType
                )
                XposedBridge.hookMethod(onDarkChangedMethod, object : XC_MethodHook() {
                    override fun afterHookedMethod(param: MethodHookParam) {
                        try {
                            val controller = param.thisObject
                            val fakeStatusView = XposedHelpers.getObjectField(
                                controller, "fakeStatusView"
                            ) as? View ?: return
                            val color = resolveBgColor(fakeStatusView.context)
                            applyColorToView(fakeStatusView, color)
                        } catch (_: Exception) {}
                    }
                })
            } catch (_: Exception) {
                // onDarkChanged hook 失败不影响主功能
            }

            XposedBridge.log("HyperIsland[FocusNotifColorHook]: hooked updateFakeFocusNotifView + onDarkChanged")
        } catch (e: Exception) {
            XposedBridge.log("HyperIsland[FocusNotifColorHook]: init error: ${e.message}")
        }
    }
}
