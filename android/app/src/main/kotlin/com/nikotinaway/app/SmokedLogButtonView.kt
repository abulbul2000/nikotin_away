package com.nikotinaway.app

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.view.MotionEvent
import android.view.View

/// The floating quick-log button.
///
/// Deliberately press-and-hold rather than tap: this thing sits on top of
/// whatever the user is doing all day, and a stray brush against it writing
/// "I smoked" into their history would quietly corrupt the very data the
/// barrier and the risky-hour ranking are computed from. Three seconds is
/// long enough that no accidental contact reaches it.
///
/// The ring is not decoration — without visible progress a three-second hold
/// reads as a dead button, and people let go at one second and conclude it's
/// broken.
class SmokedLogButtonView(
    context: Context,
    private val onHoldCompleted: () -> Unit,
    private val onDragged: (dx: Float, dy: Float) -> Unit,
    private val onDragFinished: () -> Unit,
) : View(context) {

    private val mark = BitmapFactory.decodeResource(resources, R.drawable.smoked_log_mark)

    private val markPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        alpha = RESTING_ALPHA
    }
    private val ringPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = dp(3f)
        strokeCap = Paint.Cap.ROUND
        color = ACCENT
    }
    private val trackPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = dp(3f)
        color = Color.argb(60, 255, 255, 255)
    }
    private val tickPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = dp(4f)
        strokeCap = Paint.Cap.ROUND
        color = ACCENT
    }

    private var holdStartedAt = 0L
    private var holding = false
    private var confirming = false
    private var dragging = false
    private var downX = 0f
    private var downY = 0f

    private val bounds = RectF()

    private val ticker = object : Runnable {
        override fun run() {
            if (!holding) return
            if (progress() >= 1f) {
                completeHold()
                return
            }
            invalidate()
            postOnAnimation(this)
        }
    }

    private fun dp(value: Float) = value * resources.displayMetrics.density

    private fun progress(): Float {
        if (!holding) return 0f
        val elapsed = System.currentTimeMillis() - holdStartedAt
        return (elapsed.toFloat() / HOLD_DURATION_MS).coerceIn(0f, 1f)
    }

    @SuppressLint("ClickableViewAccessibility")
    override fun onTouchEvent(event: MotionEvent): Boolean {
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                downX = event.rawX
                downY = event.rawY
                dragging = false
                startHold()
                return true
            }

            MotionEvent.ACTION_MOVE -> {
                val dx = event.rawX - downX
                val dy = event.rawY - downY
                if (!dragging && (Math.abs(dx) > touchSlop() || Math.abs(dy) > touchSlop())) {
                    // Moving means they're repositioning the button, not
                    // answering it — abandon the hold so dragging it out of
                    // the way can never log a cigarette.
                    dragging = true
                    cancelHold()
                }
                if (dragging) {
                    onDragged(dx, dy)
                    downX = event.rawX
                    downY = event.rawY
                }
                return true
            }

            MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                if (dragging) {
                    onDragFinished()
                } else {
                    // Released early: the ring unwinds and nothing is recorded.
                    cancelHold()
                }
                dragging = false
                return true
            }
        }
        return super.onTouchEvent(event)
    }

    private fun touchSlop() = dp(8f)

    private fun startHold() {
        if (confirming) return
        holding = true
        holdStartedAt = System.currentTimeMillis()
        markPaint.alpha = ACTIVE_ALPHA
        postOnAnimation(ticker)
    }

    private fun cancelHold() {
        holding = false
        markPaint.alpha = RESTING_ALPHA
        invalidate()
    }

    private fun completeHold() {
        holding = false
        confirming = true
        markPaint.alpha = ACTIVE_ALPHA
        invalidate()
        onHoldCompleted()
        // Leave the tick up briefly so the user sees it was registered before
        // the button fades back to its resting state.
        postDelayed({
            confirming = false
            markPaint.alpha = RESTING_ALPHA
            invalidate()
        }, CONFIRM_HOLD_MS)
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val inset = dp(6f)
        bounds.set(inset, inset, width - inset, height - inset)

        val markInset = dp(14f)
        canvas.drawBitmap(
            mark,
            null,
            RectF(markInset, markInset, width - markInset, height - markInset),
            markPaint,
        )

        if (confirming) {
            drawTick(canvas)
            return
        }
        if (!holding) return

        canvas.drawArc(bounds, 0f, 360f, false, trackPaint)
        canvas.drawArc(bounds, -90f, 360f * progress(), false, ringPaint)
    }

    private fun drawTick(canvas: Canvas) {
        canvas.drawArc(bounds, 0f, 360f, false, ringPaint)
        val cx = width / 2f
        val cy = height / 2f
        val s = dp(9f)
        canvas.drawLine(cx - s, cy, cx - s / 3f, cy + s * 0.8f, tickPaint)
        canvas.drawLine(cx - s / 3f, cy + s * 0.8f, cx + s, cy - s * 0.7f, tickPaint)
    }

    companion object {
        const val HOLD_DURATION_MS = 3000L
        private const val CONFIRM_HOLD_MS = 800L

        /// Findable at a glance, full stop.
        // Resting opacity. Was 105/255 (~40%), then 190/255 (~75%) — still
        // lost against a busy wallpaper. This is a standing offer; the point
        // of the drag support is that anyone bothered by it moves it rather
        // than the button making itself harder to see.
        private const val RESTING_ALPHA = 255
        private const val ACTIVE_ALPHA = 255

        private val ACCENT = Color.parseColor("#00B8D4")
    }
}
