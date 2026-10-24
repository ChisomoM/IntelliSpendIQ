package com.intellispendiq.app

import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.text.TextUtils
import android.util.Log
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView

/**
 * The floating "What was this?" card: a window drawn over whatever app is
 * open, with the user's usual categories as buttons and a dropdown of
 * every category.
 *
 * Drawn here in plain Android views rather than Flutter on purpose. The
 * Dart engine that decides to show it is the headless one the SMS
 * receiver starts, and that is torn down within seconds; the card has to
 * stay up, and answer a tap, long after. A process showing an overlay
 * window is kept alive by Android, so nothing else is needed to hold it.
 * Picking a category starts a short headless run ([BackgroundCapture]) to
 * do the actual filing in Dart.
 *
 * Needs the "Display over other apps" permission. Without it [show]
 * returns false and the notification (always posted too) is all the user
 * gets. Everything here must run on the main thread.
 */
object NudgeOverlay {

    private const val TAG = "NudgeOverlay"
    private const val AUTO_DISMISS_MS = 30_000L
    private const val DONE_LINGER_MS = 1_400L
    private const val FAILED_LINGER_MS = 3_500L
    private const val ROW_DP = 44
    private const val MAX_LIST_DP = 220

    private val CARD = 0xFF1F2A33.toInt()
    private val ACCENT = 0xFF2E7D6B.toInt()
    private val MUTED = 0xFFB8C4CC.toInt()
    private val OUTLINE = 0xFF40505C.toInt()

    private val handler = Handler(Looper.getMainLooper())
    private var windowManager: WindowManager? = null
    private var shown: View? = null
    private val autoDismiss = Runnable { dismiss() }

    private data class Option(val id: String, val label: String)

    private data class Card(
        val transactionId: String,
        val notificationId: Int,
        val title: String,
        val body: String,
        val suggestions: List<Option>,
        val options: List<Option>,
    )

    fun canDraw(context: Context): Boolean = Settings.canDrawOverlays(context)

    /** Puts the card on screen. Returns false if it could not be shown. */
    fun show(context: Context, args: Map<*, *>): Boolean {
        val app = context.applicationContext
        if (!canDraw(app)) return false
        val card = parse(args) ?: return false
        return try {
            present(app, card)
            true
        } catch (error: Throwable) {
            Log.w(TAG, "Could not show the card", error)
            false
        }
    }

    fun dismiss() {
        handler.removeCallbacks(autoDismiss)
        val view = shown
        val manager = windowManager
        shown = null
        windowManager = null
        if (view != null && manager != null) {
            try {
                manager.removeView(view)
            } catch (error: IllegalArgumentException) {
                // Already gone, e.g. the process was recreated.
            }
        }
    }

    private fun dismissIf(view: View) {
        if (shown === view) dismiss()
    }

    private fun parse(args: Map<*, *>): Card? {
        val transactionId = args["transactionId"] as? String ?: return null
        return Card(
            transactionId = transactionId,
            notificationId = (args["notificationId"] as? Number)?.toInt() ?: 0,
            title = args["title"] as? String ?: "",
            body = args["body"] as? String ?: "",
            suggestions = options(args["suggestions"]),
            options = options(args["options"]),
        )
    }

    private fun options(raw: Any?): List<Option> =
        (raw as? List<*>)?.mapNotNull { item ->
            val map = item as? Map<*, *> ?: return@mapNotNull null
            val id = map["id"] as? String ?: return@mapNotNull null
            Option(id, map["label"] as? String ?: id)
        } ?: emptyList()

    private fun present(app: Context, card: Card) {
        dismiss() // A newer prompt replaces one still showing.
        val manager = app.getSystemService(Context.WINDOW_SERVICE) as WindowManager
        val view = build(app, card)
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
            y = statusBarHeight(app) + dp(app, 8)
        }
        manager.addView(view, params)
        windowManager = manager
        shown = view
        handler.postDelayed(autoDismiss, AUTO_DISMISS_MS)
    }

    private fun build(ctx: Context, card: Card): View {
        val root = FrameLayout(ctx).apply { setPadding(dp(ctx, 12), 0, dp(ctx, 12), 0) }
        val box = LinearLayout(ctx).apply {
            orientation = LinearLayout.VERTICAL
            background = rounded(ctx, CARD, 16)
            setPadding(dp(ctx, 16), dp(ctx, 12), dp(ctx, 16), dp(ctx, 14))
            elevation = dp(ctx, 8).toFloat()
        }
        root.addView(box)

        val header = LinearLayout(ctx).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        header.addView(
            label(ctx, card.title, 16f, Color.WHITE, bold = true),
            LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f),
        )
        header.addView(
            label(ctx, "✕", 18f, MUTED).apply {
                setPadding(dp(ctx, 12), dp(ctx, 4), dp(ctx, 4), dp(ctx, 4))
                setOnClickListener { dismissIf(root) }
            },
        )
        box.addView(header)

        // Tapping the amount opens the transaction in the app.
        box.addView(
            label(ctx, card.body, 14f, MUTED).apply {
                setPadding(0, dp(ctx, 2), 0, dp(ctx, 10))
                setOnClickListener {
                    openInApp(ctx, card.transactionId)
                    dismissIf(root)
                }
            },
        )

        val status = label(ctx, "", 14f, Color.WHITE).apply {
            visibility = View.GONE
            setPadding(0, dp(ctx, 4), 0, dp(ctx, 4))
        }
        val controls = LinearLayout(ctx).apply { orientation = LinearLayout.VERTICAL }

        fun choose(option: Option) {
            controls.visibility = View.GONE
            status.text = "Filing under ${option.label}…"
            status.visibility = View.VISIBLE
            handler.removeCallbacks(autoDismiss)
            BackgroundCapture.run(
                ctx,
                listOf(
                    "categorize" to mapOf<String, Any?>(
                        "transactionId" to card.transactionId,
                        "categoryId" to option.id,
                    ),
                ),
            ) { results ->
                val filed = results.firstOrNull() == "categorized"
                if (filed) cancelNotification(ctx, card.notificationId)
                status.text = if (filed) {
                    "Filed under ${option.label} ✓"
                } else {
                    "Could not save that. Open the app to file it."
                }
                handler.postDelayed(
                    { dismissIf(root) },
                    if (filed) DONE_LINGER_MS else FAILED_LINGER_MS,
                )
            }
        }

        if (card.suggestions.isNotEmpty()) {
            val row = LinearLayout(ctx).apply { orientation = LinearLayout.HORIZONTAL }
            card.suggestions.forEachIndexed { index, option ->
                val chip = label(ctx, option.label, 14f, Color.WHITE, bold = true).apply {
                    gravity = Gravity.CENTER
                    maxLines = 1
                    ellipsize = TextUtils.TruncateAt.END
                    background = rounded(ctx, ACCENT, 20)
                    setPadding(dp(ctx, 8), dp(ctx, 10), dp(ctx, 8), dp(ctx, 10))
                    setOnClickListener { choose(option) }
                }
                row.addView(
                    chip,
                    LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f)
                        .apply { if (index > 0) marginStart = dp(ctx, 8) },
                )
            }
            controls.addView(row)
        }

        if (card.options.isNotEmpty()) {
            val collapsed = "Another category  ▾"
            val expanded = "Another category  ▴"
            val selector = label(ctx, collapsed, 14f, Color.WHITE).apply {
                gravity = Gravity.CENTER_VERTICAL
                background = rounded(ctx, Color.TRANSPARENT, 12, stroke = OUTLINE)
                setPadding(dp(ctx, 12), dp(ctx, 12), dp(ctx, 12), dp(ctx, 12))
            }
            val list = LinearLayout(ctx).apply { orientation = LinearLayout.VERTICAL }
            for (option in card.options) {
                list.addView(
                    label(ctx, option.label, 15f, Color.WHITE).apply {
                        gravity = Gravity.CENTER_VERTICAL
                        minimumHeight = dp(ctx, ROW_DP)
                        setPadding(dp(ctx, 12), 0, dp(ctx, 12), 0)
                        setOnClickListener { choose(option) }
                    },
                )
            }
            val scroll = ScrollView(ctx).apply {
                visibility = View.GONE
                addView(list)
            }
            selector.setOnClickListener {
                val opening = scroll.visibility != View.VISIBLE
                scroll.visibility = if (opening) View.VISIBLE else View.GONE
                selector.text = if (opening) expanded else collapsed
                // Still deciding: restart the clock rather than vanish.
                handler.removeCallbacks(autoDismiss)
                handler.postDelayed(autoDismiss, AUTO_DISMISS_MS)
            }
            controls.addView(
                selector,
                LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.WRAP_CONTENT,
                ).apply { topMargin = dp(ctx, 10) },
            )
            controls.addView(
                scroll,
                LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    dp(ctx, minOf(card.options.size * ROW_DP, MAX_LIST_DP)),
                ).apply { topMargin = dp(ctx, 4) },
            )
        }

        box.addView(controls)
        box.addView(status)
        return root
    }

    private fun openInApp(ctx: Context, transactionId: String) {
        val intent = Intent(
            Intent.ACTION_VIEW,
            Uri.parse("intellispendiq://transaction/$transactionId"),
        ).setPackage(ctx.packageName).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        try {
            ctx.startActivity(intent)
        } catch (error: Exception) {
            Log.w(TAG, "Could not open the transaction", error)
        }
    }

    /** The notification the same nudge posted; filed means it is done. */
    private fun cancelNotification(ctx: Context, id: Int) {
        val manager = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.cancel(id)
    }

    private fun dp(ctx: Context, value: Int): Int =
        TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            value.toFloat(),
            ctx.resources.displayMetrics,
        ).toInt()

    private fun rounded(ctx: Context, color: Int, radiusDp: Int, stroke: Int? = null) =
        GradientDrawable().apply {
            setColor(color)
            cornerRadius = dp(ctx, radiusDp).toFloat()
            if (stroke != null) setStroke(dp(ctx, 1), stroke)
        }

    private fun label(
        ctx: Context,
        value: String,
        sizeSp: Float,
        color: Int,
        bold: Boolean = false,
    ) = TextView(ctx).apply {
        text = value
        textSize = sizeSp
        setTextColor(color)
        if (bold) setTypeface(typeface, Typeface.BOLD)
    }

    private fun statusBarHeight(ctx: Context): Int {
        val id = ctx.resources.getIdentifier("status_bar_height", "dimen", "android")
        return if (id > 0) ctx.resources.getDimensionPixelSize(id) else 0
    }
}
